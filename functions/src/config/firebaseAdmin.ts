import {getApps, initializeApp} from "firebase-admin/app";
import {getAuth} from "firebase-admin/auth";
import {getFirestore} from "firebase-admin/firestore";

const firebaseApp = getApps().length === 0 ?
  initializeApp() :
  getApps()[0];

export const adminAuth = getAuth(firebaseApp);
export const firestore = getFirestore(firebaseApp);
