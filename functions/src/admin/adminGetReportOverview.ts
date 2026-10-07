/* eslint-disable max-len */
/* eslint-disable require-jsdoc */
import {onCall} from "firebase-functions/v2/https";
import {DocumentData, Timestamp, getFirestore} from "firebase-admin/firestore";
import {
  assertAdminPermission,
  getAdminRole,
} from "../security/adminAuthorization";
import {writeAuditLog} from "../audit/writeAuditLog";

export const adminGetReportOverview = onCall(
  {region: "europe-west1", enforceAppCheck: true},
  async (request) => {
    assertAdminPermission(request, "reports.read");

    const adminId = request.auth.uid;
    const adminRole = getAdminRole(request);
    const db = getFirestore();

    const twentyFourHoursAgo = Timestamp.fromMillis(
      Date.now() - 24 * 60 * 60 * 1000,
    );
    const staleThreshold = twentyFourHoursAgo.toDate();

    const [
      usersSnapshot,
      eventsSnapshot,
      supportSnapshot,
      paymentSessionsSnapshot,
      withdrawalsSnapshot,
      verificationSnapshot,
      maskedCallsSnapshot,
      recentAuditCount,
    ] = await Promise.all([
      db.collection("users").select(
        "plus",
        "oyuncuRozeti",
        "verified",
        "verificationStatus",
        "role",
        "admin",
        "olusturmaTarihi",
        "createdAt",
        "kayitTarihi",
      ).get(),
      db.collection("events").select("status", "durum").get(),
      db.collection("support_requests").select("status", "urgency").get(),
      db.collection("paymentSessions").select(
        "status",
        "gatewayStatus",
        "providerState",
        "updatedAt",
        "createdAt",
      ).get(),
      db.collection("withdrawals").select(
        "status",
        "updatedAt",
        "createdAt",
      ).get(),
      db.collection("verification_requests").select(
        "status",
        "updatedAt",
        "createdAt",
      ).get(),
      db.collection("masked_call_requests")
        .where("createdAt", ">=", twentyFourHoursAgo)
        .select("status")
        .get(),
      db.collection("audit_logs")
        .where("createdAt", ">=", twentyFourHoursAgo)
        .count()
        .get(),
    ]);

    const now = new Date();
    const startOfToday = new Date(
      now.getFullYear(),
      now.getMonth(),
      now.getDate(),
    );
    const startOfWeek = new Date(startOfToday);
    startOfWeek.setDate(
      startOfToday.getDate() - ((startOfToday.getDay() + 6) % 7),
    );

    let plusUsers = 0;
    let playerUsers = 0;
    let adminUsers = 0;
    let todayUsers = 0;
    let weekUsers = 0;

    for (const document of usersSnapshot.docs) {
      const data = document.data();

      if (data.plus === true) {
        plusUsers++;
      }

      if (
        data.oyuncuRozeti === true ||
        data.verified === true ||
        data.verificationStatus === "approved"
      ) {
        playerUsers++;
      }

      const role = lowerString(data.role);

      if (
        data.admin === true ||
        [
          "moderator",
          "verification_officer",
          "support_officer",
          "finance_officer",
          "content_manager",
          "analyst",
          "admin",
          "super_admin",
        ].includes(role)
      ) {
        adminUsers++;
      }

      const createdAt = readDate(
        data.olusturmaTarihi ??
        data.createdAt ??
        data.kayitTarihi,
      );

      if (createdAt) {
        if (createdAt >= startOfToday) {
          todayUsers++;
        }

        if (createdAt >= startOfWeek) {
          weekUsers++;
        }
      }
    }

    let activeEvents = 0;
    let completedEvents = 0;
    let cancelledEvents = 0;
    let hiddenEvents = 0;

    for (const document of eventsSnapshot.docs) {
      const status = normalizeEventStatus(document.data());

      if (status === "completed") {
        completedEvents++;
      } else if (status === "cancelled") {
        cancelledEvents++;
      } else if (status === "hidden") {
        hiddenEvents++;
      } else {
        activeEvents++;
      }
    }

    let newSupport = 0;
    let reviewingSupport = 0;
    let answeredSupport = 0;
    let closedSupport = 0;
    let criticalSupport = 0;

    for (const document of supportSnapshot.docs) {
      const data = document.data();
      const status = lowerString(data.status) || "new";
      const urgency = lowerString(data.urgency) || "normal";

      if (status === "reviewing") {
        reviewingSupport++;
      } else if (status === "answered") {
        answeredSupport++;
      } else if (status === "closed") {
        closedSupport++;
      } else {
        newSupport++;
      }

      if (urgency === "critical") {
        criticalSupport++;
      }
    }

    let pendingPayments = 0;
    let paidPayments = 0;
    let failedPayments = 0;
    let stalePendingPayments = 0;

    for (const document of paymentSessionsSnapshot.docs) {
      const data = document.data();
      const status = lowerString(
        data.status ??
        data.gatewayStatus ??
        data.providerState,
      );

      if (["paid", "completed", "success", "succeeded"].includes(status)) {
        paidPayments++;
      } else if ([
        "failed",
        "cancelled",
        "canceled",
        "expired",
      ].includes(status)) {
        failedPayments++;
      } else {
        pendingPayments++;

        const pendingSince = readDate(
          data.updatedAt ??
          data.createdAt,
        );

        if (pendingSince && pendingSince < staleThreshold) {
          stalePendingPayments++;
        }
      }
    }

    let pendingWithdrawals = 0;
    let stalePendingWithdrawals = 0;

    for (const document of withdrawalsSnapshot.docs) {
      const data = document.data();

      if (lowerString(data.status) === "pending") {
        pendingWithdrawals++;

        const pendingSince = readDate(
          data.updatedAt ??
          data.createdAt,
        );

        if (pendingSince && pendingSince < staleThreshold) {
          stalePendingWithdrawals++;
        }
      }
    }

    let pendingVerifications = 0;
    let stalePendingVerifications = 0;

    for (const document of verificationSnapshot.docs) {
      const data = document.data();
      const status = lowerString(data.status);

      if (status === "pending" || status === "reviewing") {
        pendingVerifications++;

        const pendingSince = readDate(
          data.updatedAt ??
          data.createdAt,
        );

        if (pendingSince && pendingSince < staleThreshold) {
          stalePendingVerifications++;
        }
      }
    }

    let unavailableMaskedCalls = 0;

    for (const document of maskedCallsSnapshot.docs) {
      if (lowerString(document.data().status) === "provider_not_configured") {
        unavailableMaskedCalls++;
      }
    }

    const attentionRequired =
      failedPayments +
      stalePendingPayments +
      stalePendingWithdrawals +
      stalePendingVerifications +
      criticalSupport;

    await writeAuditLog({
      action: "admin_report_overview_viewed",
      performedBy: adminId,
      metadata: {
        performedByRole: adminRole,
      },
    });

    return {
      generatedAt: Date.now(),
      users: {
        total: usersSnapshot.size,
        today: todayUsers,
        week: weekUsers,
        plus: plusUsers,
        player: playerUsers,
        admins: adminUsers,
      },
      events: {
        total: eventsSnapshot.size,
        active: activeEvents,
        completed: completedEvents,
        cancelled: cancelledEvents,
        hidden: hiddenEvents,
      },
      support: {
        total: supportSnapshot.size,
        new: newSupport,
        reviewing: reviewingSupport,
        answered: answeredSupport,
        closed: closedSupport,
        critical: criticalSupport,
      },
      operations: {
        paymentSessions: paymentSessionsSnapshot.size,
        pendingPayments,
        paidPayments,
        failedPayments,
        stalePendingPayments,
        pendingWithdrawals,
        stalePendingWithdrawals,
        pendingVerifications,
        stalePendingVerifications,
        attentionRequired,
        maskedCallsLast24h: maskedCallsSnapshot.size,
        unavailableMaskedCalls,
        auditEventsLast24h: recentAuditCount.data().count,
      },
    };
  },
);

function lowerString(value: unknown): string {
  if (typeof value !== "string") {
    return "";
  }

  return value.toLowerCase();
}

function readDate(value: unknown): Date | null {
  if (value instanceof Timestamp) {
    return value.toDate();
  }

  if (value instanceof Date) {
    return value;
  }

  if (typeof value === "string") {
    const parsed = new Date(value);

    if (!Number.isNaN(parsed.getTime())) {
      return parsed;
    }
  }

  return null;
}

function normalizeEventStatus(
  data: DocumentData,
): "active" | "completed" | "cancelled" | "hidden" {
  let raw = "";

  if (typeof data.status === "string") {
    raw = data.status;
  } else if (typeof data.durum === "string") {
    raw = data.durum;
  }

  const value = raw.toLowerCase();

  if (
    value === "completed" ||
    value === "finished" ||
    value === "tamamlandi" ||
    value === "tamamlandı"
  ) {
    return "completed";
  }

  if (
    value === "cancelled" ||
    value === "canceled" ||
    value === "iptal" ||
    value === "cancelled_by_host"
  ) {
    return "cancelled";
  }

  if (
    value === "hidden" ||
    value === "removed" ||
    value === "gizli"
  ) {
    return "hidden";
  }

  return "active";
}
