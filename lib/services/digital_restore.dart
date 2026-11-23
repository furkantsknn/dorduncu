import 'purchase_flow_reconcile.dart';

enum DigitalRestorePresentation {
  completed,
  giftKept,
  paymentPending,
  notFound,
}

enum MarketRestoreFeedbackKind {
  none,
  running,
  completed,
  giftKept,
  paymentPending,
  notFound,
  failed,
  blocked,
}

class MarketRestoreFeedback {
  const MarketRestoreFeedback._({
    required this.kind,
    this.detail,
    this.blockedReason,
  });

  const MarketRestoreFeedback.none()
    : this._(kind: MarketRestoreFeedbackKind.none);

  const MarketRestoreFeedback.running()
    : this._(kind: MarketRestoreFeedbackKind.running);

  const MarketRestoreFeedback.completed()
    : this._(kind: MarketRestoreFeedbackKind.completed);

  const MarketRestoreFeedback.giftKept()
    : this._(kind: MarketRestoreFeedbackKind.giftKept);

  const MarketRestoreFeedback.paymentPending()
    : this._(kind: MarketRestoreFeedbackKind.paymentPending);

  const MarketRestoreFeedback.notFound()
    : this._(kind: MarketRestoreFeedbackKind.notFound);

  const MarketRestoreFeedback.failed(String message)
    : this._(kind: MarketRestoreFeedbackKind.failed, detail: message);

  const MarketRestoreFeedback.blocked(MarketRestoreReason reason)
    : this._(kind: MarketRestoreFeedbackKind.blocked, blockedReason: reason);

  final MarketRestoreFeedbackKind kind;
  final String? detail;
  final MarketRestoreReason? blockedReason;

  bool get visible => kind != MarketRestoreFeedbackKind.none;
}

class DigitalRestoreResult {
  const DigitalRestoreResult({
    this.verifiedForAccount = 0,
    this.giftsKeptWithRecipient = 0,
    this.pendingPayments = 0,
  });

  final int verifiedForAccount;
  final int giftsKeptWithRecipient;
  final int pendingPayments;

  DigitalRestorePresentation get presentation {
    return classifyDigitalRestore(
      verifiedForAccount: verifiedForAccount,
      giftsKeptWithRecipient: giftsKeptWithRecipient,
      pendingPayments: pendingPayments,
    );
  }
}

DigitalRestorePresentation classifyDigitalRestore({
  required int verifiedForAccount,
  required int giftsKeptWithRecipient,
  int pendingPayments = 0,
}) {
  if (verifiedForAccount > 0) {
    return DigitalRestorePresentation.completed;
  }
  if (giftsKeptWithRecipient > 0) {
    return DigitalRestorePresentation.giftKept;
  }
  if (pendingPayments > 0) {
    return DigitalRestorePresentation.paymentPending;
  }
  return DigitalRestorePresentation.notFound;
}
