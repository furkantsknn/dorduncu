import 'package:cloud_firestore/cloud_firestore.dart';

import 'notification_service.dart';
import 'wallet_service.dart';

enum PaymentStatus {
  created,
  escrowPending,
  escrowHeld,
  eventStarted,
  waitingCustomerApprove,
  waitingPlayerApprove,
  completed,
  cancelledByCustomer,
  cancelledByOrganizer,
  refunded,
  dispute,
}

class PaymentService {
PaymentService._();

static final FirebaseFirestore _firestore =
FirebaseFirestore.instance;

static CollectionReference<Map<String, dynamic>>
get payments =>
_firestore.collection('payments');

static CollectionReference<Map<String, dynamic>>
get paymentLogs =>
_firestore.collection('payment_logs');

static String statusToString(
PaymentStatus status) {
switch (status) {
case PaymentStatus.created:
return 'created';

case PaymentStatus.escrowPending:
return 'escrow_pending';

case PaymentStatus.escrowHeld:
return 'escrow_held';

case PaymentStatus.eventStarted:
return 'event_started';

case PaymentStatus.waitingCustomerApprove:
return 'waiting_customer_approve';

case PaymentStatus.waitingPlayerApprove:
return 'waiting_player_approve';

case PaymentStatus.completed:
return 'completed';

case PaymentStatus.cancelledByCustomer:
return 'customer_cancelled';

case PaymentStatus.cancelledByOrganizer:
return 'organizer_cancelled';

case PaymentStatus.refunded:
return 'refunded';

case PaymentStatus.dispute:
return 'dispute';
}
}

static Future<DocumentSnapshot<Map<String, dynamic>>>
getPayment(String paymentId) {
return payments.doc(paymentId).get();
}

static Future<void> log({
required String paymentId,
required String action,
required String performedBy,
Map<String, dynamic>? extra,
}) async {
await paymentLogs.add({
"paymentId": paymentId,
"action": action,
"performedBy": performedBy,
"extra": extra ?? {},
"createdAt": FieldValue.serverTimestamp(),
});
}

static Future<void> updateStatus({
required String paymentId,
required PaymentStatus status,
}) async {
await payments.doc(paymentId).update({
"status": statusToString(status),
"updatedAt": FieldValue.serverTimestamp(),
});
}

static Future<String> createEscrowPayment({
required String eventId,
required String eventTitle,
required String customerUid,
required List<String> playerUids,
required int customerTotalKurus,
required int playerGrossKurus,
required int platformShareKurus,
}) async {
final paymentRef = payments.doc();

await paymentRef.set({
"eventId": eventId,
"eventTitle": eventTitle,

"customerUid": customerUid,

"playerUids": playerUids,

"customerTotalKurus":
customerTotalKurus,

"playerGrossKurus":
playerGrossKurus,

"platformShareKurus":
platformShareKurus,

"status":
statusToString(
PaymentStatus.escrowPending),

"customerApproved": false,

"playersApproved": <String>[],

"refundKurus": 0,

"dispute": false,

"platformReleased": false,

"playerReleased": false,

"createdAt":
FieldValue.serverTimestamp(),

"updatedAt":
FieldValue.serverTimestamp(),
});

await _firestore
.collection("events")
.doc(eventId)
.set({
"paymentId": paymentRef.id,

"paymentRequired": true,

"paymentStatus":
statusToString(
PaymentStatus.escrowPending),

"updatedAt":
FieldValue.serverTimestamp(),
}, SetOptions(merge: true));

await log(
paymentId: paymentRef.id,
action: "payment_created",
performedBy: customerUid,
);

return paymentRef.id;
}

static Future<void> confirmPayment({
required String paymentId,
}) async {
final snapshot =
await payments.doc(paymentId).get();

if (!snapshot.exists) {
throw Exception("Payment not found");
}

final data = snapshot.data()!;

final eventId =
data["eventId"] ?? "";

final eventTitle =
data["eventTitle"] ?? "";

final players =
List<String>.from(
data["playerUids"] ?? []);

final total =
data["playerGrossKurus"] ?? 0;

final each =
players.isEmpty
? 0
: total ~/ players.length;

final batch =
_firestore.batch();

batch.update(
payments.doc(paymentId),
{
"status":
statusToString(
PaymentStatus.escrowHeld),

"paidAt":
FieldValue.serverTimestamp(),

"updatedAt":
FieldValue.serverTimestamp(),
},
);

batch.set(
_firestore
.collection("events")
.doc(eventId),
{
"paymentStatus":
statusToString(
PaymentStatus.escrowHeld),

"updatedAt":
FieldValue.serverTimestamp(),
},
SetOptions(merge: true),
);

for (final uid in players) {
batch.set(
WalletService.walletRef(uid),
{
"pendingBalanceKurus":
FieldValue.increment(each),

"updatedAt":
FieldValue.serverTimestamp(),
},
SetOptions(merge: true),
);
}

await batch.commit();

for (final uid in players) {
await NotificationService.send(
userUid: uid,
type: "payment",

title: "Ödeme Alındı",

message:
"$eventTitle etkinliği için ödeme emanet hesabına alındı.",

eventId: eventId,
eventTitle: eventTitle,
);
}

await log(
paymentId: paymentId,
action: "payment_confirmed",
performedBy: "system",
);
}
static Future<void> customerApproveFinish({
required String paymentId,
required String customerUid,
}) async {
final payment =
await payments.doc(paymentId).get();

if (!payment.exists) {
throw Exception("Payment not found");
}

final data = payment.data()!;

if (data["customerApproved"] == true) {
return;
}

await payments.doc(paymentId).update({
"customerApproved": true,
"customerApprovedAt":
FieldValue.serverTimestamp(),
"status": statusToString(
PaymentStatus.waitingPlayerApprove),
"updatedAt":
FieldValue.serverTimestamp(),
});

await log(
paymentId: paymentId,
action: "customer_approved_finish",
performedBy: customerUid,
);
}

static Future<void> playerApproveFinish({
required String paymentId,
required String playerUid,
}) async {
final payment =
await payments.doc(paymentId).get();

if (!payment.exists) {
throw Exception("Payment not found");
}

final data = payment.data()!;

final approved =
List<String>.from(
data["playersApproved"] ?? []);

if (!approved.contains(playerUid)) {
approved.add(playerUid);
}

await payments.doc(paymentId).update({
"playersApproved": approved,
"updatedAt":
FieldValue.serverTimestamp(),
});

await log(
paymentId: paymentId,
action: "player_approved_finish",
performedBy: playerUid,
);

final players =
List<String>.from(
data["playerUids"] ?? []);

if (approved.length == players.length &&
data["customerApproved"] == true) {
await releaseEscrow(paymentId);
}
}

static Future<void> releaseEscrow(
String paymentId) async {
final payment =
await payments.doc(paymentId).get();

if (!payment.exists) {
throw Exception("Payment not found");
}

final data = payment.data()!;

if (data["playerReleased"] == true) {
return;
}

final players =
List<String>.from(
data["playerUids"] ?? []);

final gross =
data["playerGrossKurus"] ?? 0;

final each =
players.isEmpty
? 0
: gross ~/ players.length;

for (final uid in players) {
  await WalletService.movePendingToAvailable(
    uid: uid,
    amountKurus: each,
    eventId: data["eventId"],
    eventTitle: data["eventTitle"],
    paymentId: paymentId,
    referenceId: paymentId,
  );

await NotificationService.send(
userUid: uid,
type: "wallet",
title: "Kazanç Hesabına Aktarıldı",
message:
"${(each / 100).toStringAsFixed(2)} ₺ kullanılabilir bakiyene aktarıldı.",
);
}

await payments.doc(paymentId).update({
"playerReleased": true,
"releasedAt":
FieldValue.serverTimestamp(),
"status":
statusToString(
PaymentStatus.completed),
"updatedAt":
FieldValue.serverTimestamp(),
});

await log(
paymentId: paymentId,
action: "escrow_released",
performedBy: "system",
);
}

static Future<void> openDispute({
required String paymentId,
required String openedBy,
required String reason,
}) async {
await payments.doc(paymentId).update({
"status":
statusToString(
PaymentStatus.dispute),
"dispute": true,
"disputeReason": reason,
"disputeOpenedBy": openedBy,
"disputeOpenedAt":
FieldValue.serverTimestamp(),
"updatedAt":
FieldValue.serverTimestamp(),
});

await log(
paymentId: paymentId,
action: "dispute_opened",
performedBy: openedBy,
extra: {
"reason": reason,
},
);
}

static Future<void> closeDispute({
required String paymentId,
required bool releasePayment,
}) async {
if (releasePayment) {
await releaseEscrow(paymentId);
} else {
await updateStatus(
paymentId: paymentId,
status: PaymentStatus.refunded,
);
}

await payments.doc(paymentId).update({
"dispute": false,
"disputeClosedAt":
FieldValue.serverTimestamp(),
});

await log(
paymentId: paymentId,
action: "dispute_closed",
performedBy: "admin",
);
}
static Future<void> organizerCancellation({
  required String paymentId,
  required String organizerUid,
  required String reason,
}) async {
  final snapshot = await payments.doc(paymentId).get();

  if (!snapshot.exists) {
    throw Exception("Payment not found");
  }

  final data = snapshot.data()!;

  final customerUid = data["customerUid"];

  final customerTotal =
  (data["customerTotalKurus"] ?? 0) as int;

  await WalletService.creditRefund(
    uid: customerUid,
    amountKurus: customerTotal,
    referenceId: paymentId,
    paymentId: paymentId,
    description: "Organizatör iptali",
  );

  await payments.doc(paymentId).update({
    "status": statusToString(
        PaymentStatus.cancelledByOrganizer),
    "refundKurus": customerTotal,
    "cancelReason": reason,
    "cancelledBy": organizerUid,
    "cancelledAt":
    FieldValue.serverTimestamp(),
    "updatedAt":
    FieldValue.serverTimestamp(),
  });

  await NotificationService.send(
    userUid: customerUid,
    type: "refund",
    title: "Etkinlik İptal Edildi",
    message:
    "Ödemenizin tamamı iade bakiyenize aktarıldı.",
  );

  await log(
    paymentId: paymentId,
    action: "organizer_cancelled",
    performedBy: organizerUid,
  );
}

static Future<void> fullRefund({
  required String paymentId,
}) async {
  final snapshot = await payments.doc(paymentId).get();

  if (!snapshot.exists) {
    throw Exception("Payment not found");
  }

  final data = snapshot.data()!;

  final customerUid = data["customerUid"];

  final amount =
  (data["customerTotalKurus"] ?? 0) as int;

  await WalletService.creditRefund(
    uid: customerUid,
    amountKurus: amount,
    description: "Tam iade",
    referenceId: paymentId,
  );

  await payments.doc(paymentId).update({
    "status":
    statusToString(
        PaymentStatus.refunded),
    "refundKurus": amount,
    "refundedAt":
    FieldValue.serverTimestamp(),
    "updatedAt":
    FieldValue.serverTimestamp(),
  });

  await log(
    paymentId: paymentId,
    action: "full_refund",
    performedBy: "system",
  );
}

static Future<void> partialRefund({
  required String paymentId,
  required int refundKurus,
}) async {
  final snapshot = await payments.doc(paymentId).get();

  if (!snapshot.exists) {
    throw Exception("Payment not found");
  }

  final customerUid =
  snapshot["customerUid"];

  await WalletService.creditRefund(
    uid: customerUid,
    amountKurus: refundKurus,
    referenceId: paymentId,
    paymentId: paymentId,
    description: "Kısmi iade",
  );

  await payments.doc(paymentId).update({
    "refundKurus":
    FieldValue.increment(refundKurus),
    "updatedAt":
    FieldValue.serverTimestamp(),
  });

  await log(
    paymentId: paymentId,
    action: "partial_refund",
    performedBy: "system",
    extra: {
      "refundKurus": refundKurus,
    },
  );
}

static Future<void> autoReleaseExpiredPayments()
async {
  final query = await payments
      .where(
    "status",
    isEqualTo:
    statusToString(
        PaymentStatus.waitingPlayerApprove),
  )
      .get();

  for (final doc in query.docs) {
    final data = doc.data();

    final paidAt =
    data["paidAt"] as Timestamp?;

    if (paidAt == null) {
      continue;
    }

    final diff = DateTime.now()
        .difference(paidAt.toDate());

    if (diff.inHours >= 48) {
      await releaseEscrow(doc.id);
    }
  }
}

static bool canChangeStatus({
  required String current,
  required PaymentStatus next,
}) {
  switch (current) {
    case "escrow_pending":
      return next ==
          PaymentStatus.escrowHeld;

    case "escrow_held":
      return next ==
          PaymentStatus
              .waitingPlayerApprove ||
          next ==
              PaymentStatus
                  .cancelledByCustomer ||
          next ==
              PaymentStatus
                  .cancelledByOrganizer;

    case "waiting_player_approve":
      return next ==
          PaymentStatus.completed ||
          next ==
              PaymentStatus.dispute;

    case "dispute":
      return next ==
          PaymentStatus.completed ||
          next ==
              PaymentStatus.refunded;

    default:
      return false;
  }
}

static Future<bool> paymentExists(
    String paymentId) async {
  return (await payments
      .doc(paymentId)
      .get())
      .exists;
}

static Future<bool> alreadyReleased(
    String paymentId) async {
  final doc =
  await payments.doc(paymentId).get();

  if (!doc.exists) {
    return false;
  }

  return doc["playerReleased"] == true;
}

static Future<void> safeRelease(
    String paymentId) async {
  if (await alreadyReleased(paymentId)) {
    return;
  }

  await releaseEscrow(paymentId);
}

static Future<List<QueryDocumentSnapshot<
    Map<String, dynamic>>>> history({
  required String uid,
}) async {
  final result = await payments
      .where(
    "customerUid",
    isEqualTo: uid,
  )
      .orderBy(
    "createdAt",
    descending: true,
  )
      .get();

  return result.docs;
}
}