import {setGlobalOptions} from "firebase-functions";
import {setUserRole} from "./auth/setUserRole";
import {createEvent} from "./events/createEvent";
import {acceptApplication} from "./events/acceptApplication";
import {rejectApplication} from "./events/rejectApplication";
import {removeSelectedPlayer} from "./events/removeSelectedPlayer";
import {cancelUnpaidEvent} from "./events/cancelUnpaidEvent";
import {updateUserStatus} from "./users/updateUserStatus";
import {markEventCompleted} from "./events/markEventCompleted";
import {withdrawApplication} from "./events/withdrawApplication";
import {purchaseBadge} from "./market/purchaseBadge";
import {purchasePlus} from "./market/purchasePlus";
import {seedBadgeProducts} from "./market/seedBadgeProducts";
import {requestWithdrawal} from "./wallet/requestWithdrawal";
import {cancelWithdrawal} from "./wallet/cancelWithdrawal";
export {processVerification} from "./users/processVerification";
export {submitVerification} from "./users/submitVerification";
export {processAccountStatus} from "./users/processAccountStatus";
export {processAccountDeletion} from "./users/processAccountDeletion";
export {requestAccountDeletion} from "./users/requestAccountDeletion";
export {syncPublicProfile} from "./users/syncPublicProfile";
export {refreshAccountStatus} from "./users/refreshAccountStatus";
export {recordLoginHistory} from "./users/recordLoginHistory";
export {
  analyzeVerification,
  analyzeVerificationOnWrite,
} from "./users/analyzeVerification";

setGlobalOptions({
  maxInstances: 10,
});

export {
  createEvent,
  acceptApplication,
  rejectApplication,
  removeSelectedPlayer,
  cancelUnpaidEvent,
  markEventCompleted,
  withdrawApplication,
  setUserRole,
  updateUserStatus,
  purchaseBadge,
  purchasePlus,
  seedBadgeProducts,
  requestWithdrawal,
  cancelWithdrawal,
};

export {checkDeletedPhone} from "./users/checkDeletedPhone";
