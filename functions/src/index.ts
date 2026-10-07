import {setGlobalOptions} from "firebase-functions";

import {setUserRole} from "./auth/setUserRole";

import {createEvent} from "./events/createEvent";
import {updateEvent} from "./events/updateEvent";
import {applyToEvent} from "./events/applyToEvent";
import {acceptApplication} from "./events/acceptApplication";
import {rejectApplication} from "./events/rejectApplication";
import {removeSelectedPlayer} from "./events/removeSelectedPlayer";
import {cancelUnpaidEvent} from "./events/cancelUnpaidEvent";
import {
  completePastEvents,
  markEventCompleted,
} from "./events/markEventCompleted";
import {withdrawApplication} from "./events/withdrawApplication";
import {leaveEvent} from "./events/leaveEvent";


import {purchaseBadge} from "./market/purchaseBadge";
import {purchasePlus} from "./market/purchasePlus";
import {seedBadgeProducts} from "./market/seedBadgeProducts";

import {requestWithdrawal} from "./wallet/requestWithdrawal";
import {cancelWithdrawal} from "./wallet/cancelWithdrawal";
import {startPayment} from "./payments/startPayment";
import {sendFriendRequest} from "./friends/sendFriendRequest";
import {acceptFriendRequest} from "./friends/acceptFriendRequest";
import {rejectFriendRequest} from "./friends/rejectFriendRequest";
import {cancelFriendRequest} from "./friends/cancelFriendRequest";
import {removeFriend} from "./friends/removeFriend";
import {notifyOnEventMessage} from "./chat/notifyOnEventMessage";

export {processVerification} from "./users/processVerification";
export {submitVerification} from "./users/submitVerification";
export {processAccountStatus} from "./users/processAccountStatus";
export {processAccountDeletion} from "./users/processAccountDeletion";
export {requestAccountDeletion} from "./users/requestAccountDeletion";
export {syncPublicProfile} from "./users/syncPublicProfile";
export {syncPublicMarketBadges} from "./users/syncPublicMarketBadges";
export {refreshAccountStatus} from "./users/refreshAccountStatus";
export {recordLoginHistory} from "./users/recordLoginHistory";
export {registerSession} from "./users/registerSession";

export {
  analyzeVerification,
  analyzeVerificationOnWrite,
} from "./users/analyzeVerification";

export {checkDeletedPhone} from "./users/checkDeletedPhone";

export {adminAdjustWallet} from "./admin/adminAdjustWallet";
export {adminUpdateMembership} from "./admin/adminUpdateMembership";
export {
  adminSetGooglePlayProductId,
} from "./admin/adminSetGooglePlayProductId";
export {adminUpdateEventStatus} from "./admin/adminUpdateEventStatus";
export {adminCreateNotification} from "./admin/adminCreateNotification";
export {adminSaveMarketProduct} from "./admin/adminSaveMarketProduct";
export {adminDeleteMarketProduct} from "./admin/adminDeleteMarketProduct";
export {adminUpdateSystemSettings} from "./admin/adminUpdateSystemSettings";
export {adminGetReportOverview} from "./admin/adminGetReportOverview";

export {createSupportRequest} from "./support/createSupportRequest";

export {requestMaskedEventCall} from "./calls/requestMaskedEventCall";

setGlobalOptions({
  maxInstances: 10,
});

export {
  createEvent,
  updateEvent,
  applyToEvent,
  acceptApplication,
  rejectApplication,
  removeSelectedPlayer,
  cancelUnpaidEvent,
  markEventCompleted,
  completePastEvents,
  withdrawApplication,
  leaveEvent,
  setUserRole,
  purchaseBadge,
  purchasePlus,
  seedBadgeProducts,
  requestWithdrawal,
  cancelWithdrawal,
  startPayment,
  sendFriendRequest,
  acceptFriendRequest,
  rejectFriendRequest,
  cancelFriendRequest,
  removeFriend,
  notifyOnEventMessage,
};

export {adminUpdateSupportRequest} from "./support/adminUpdateSupportRequest";

export {adminReplySupportRequest} from "./support/adminReplySupportRequest";

export {replySupportRequest} from "./support/replySupportRequest";

export {
  updateOwnSupportRequestStatus,
} from "./support/updateOwnSupportRequestStatus";

export {
  adminMigrateSupportPrivateNotes,
} from "./support/adminMigrateSupportPrivateNotes";

export {
  getVerificationDocumentContent,
} from "./users/getVerificationDocumentContent";

export {
  adminMigrateVerificationDocumentPaths,
} from "./users/adminMigrateVerificationDocumentPaths";

export {
  claimVerificationRequest,
} from "./users/claimVerificationRequest";

export {
  requestVerificationDocumentDeletion,
} from "./users/requestVerificationDocumentDeletion";

export {
  cleanupVerificationDocuments,
} from "./users/cleanupVerificationDocuments";

export {
  adminMigrateVerificationDecisionReasons,
} from "./users/adminMigrateVerificationDecisionReasons";


export {
  expireEventPaymentReservations,
} from "./events/expireEventPaymentReservations";

export {
  registerNotificationDevice,
  unregisterNotificationDevice,
} from "./users/registerNotificationDevice";

export {
  deliverUserNotification,
} from "./notifications/deliverUserNotification";

export {
  processNotificationDeliveryQueue,
} from "./notifications/processNotificationDeliveryQueue";

export {
  sendEventMessage,
  editEventMessage,
  deleteEventMessage,
} from "./chat/manageEventMessage";

export {
  submitEventRating,
  getEventRatingState,
} from "./events/eventRatings";

export {
  adminSanitizeEventChatPreviews,
} from "./admin/adminSanitizeEventChatPreviews";

export {
  fulfillGooglePlayPurchase,
} from "./market/fulfillGooglePlayPurchase";

export {
  processGooglePlayRtdn,
} from "./commercial/googlePlayRtdn";
