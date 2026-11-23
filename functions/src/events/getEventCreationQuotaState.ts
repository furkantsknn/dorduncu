import {HttpsError, onCall} from "firebase-functions/v2/https";
import {firestore} from "../config/firebaseAdmin";

import {
  hasAdminPermission, assertCurrentAdminSession,
} from "../security/adminAuthorization";
import {isPlusMembershipActive} from "../users/plusMembership";
import {buildEventQuotaState, readOpenEventIds} from "./eventOpenQuotaPolicy";

export const getEventCreationQuotaState = onCall(
  {region: "europe-west1", enforceAppCheck: true},
  async (request) => {
    const callerUid = request.auth?.uid;
    if (!callerUid) {
      throw new HttpsError("unauthenticated", "Giriş gerekli.");
    }
    const requestedUid = String(request.data?.uid ?? callerUid).trim();
    if (requestedUid !== callerUid &&
        !hasAdminPermission(request, "users.read") &&
        !hasAdminPermission(request, "users.moderate")) {
      throw new HttpsError(
        "permission-denied",
        "Bu kota bilgisine erişemezsiniz.",
      );
    }
    if (requestedUid !== callerUid) await assertCurrentAdminSession(request);
    const user = await firestore.collection("users").doc(requestedUid).get();
    if (!user.exists) {
      throw new HttpsError("not-found", "Kullanıcı bulunamadı.");
    }
    const nowMs = Date.now();
    const plusActive = isPlusMembershipActive(user.data() ?? {}, nowMs);
    const ids = await readOpenEventIds(firestore, requestedUid, nowMs);
    const state = buildEventQuotaState(ids, plusActive);
    return {
      openEventCount: state.openEventCount,
      plusActive: state.plusActive,
      limit: state.limit,
      canCreate: state.canCreate,
    };
  },
);
