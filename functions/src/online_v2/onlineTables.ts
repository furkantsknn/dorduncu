/* eslint-disable require-jsdoc */
import {DocumentData, getFirestore} from "firebase-admin/firestore";
import {HttpsError, onCall} from "firebase-functions/v2/https";

import {
  acceptOnlineV2Invite,
  assertCanInvite,
  createOnlineV2Table,
  heartbeatOnlineV2Table,
  leaveOnlineV2Table,
  type OnlineV2Game,
  type OnlineV2Invite,
  type OnlineV2Table,
  publicOnlineV2Table,
  rejectOnlineV2Move,
} from "./tableAuthority";

const region = "europe-west1";

function assertEmulator(): void {
  if (process.env.FUNCTIONS_EMULATOR !== "true") {
    throw new HttpsError(
      "failed-precondition",
      "Online V2 masaları yalnızca emülatörde açılır.",
    );
  }
}

function requireUid(uid: string | undefined): string {
  if (!uid) {
    throw new HttpsError(
      "unauthenticated",
      "Bu işlem için kullanıcı girişi gereklidir.",
    );
  }
  return uid;
}

function requireGame(value: unknown): OnlineV2Game {
  if (
    value === "okey" ||
    value === "okey101" ||
    value === "batak" ||
    value === "tavla"
  ) {
    return value;
  }
  throw new HttpsError("invalid-argument", "Oyun türü geçersiz.");
}

function requireText(value: unknown, message: string): string {
  if (typeof value !== "string" || value.trim().length === 0) {
    throw new HttpsError("invalid-argument", message);
  }
  return value.trim();
}

async function areFriends(left: string, right: string): Promise<boolean> {
  const db = getFirestore();
  const [forward, backward] = await Promise.all([
    db.doc(`users/${left}/friends/${right}`).get(),
    db.doc(`users/${right}/friends/${left}`).get(),
  ]);
  return forward.exists && backward.exists;
}

async function eitherBlocked(
  left: string,
  right: string,
): Promise<boolean> {
  const db = getFirestore();
  const [forward, backward] = await Promise.all([
    db.doc(`users/${left}/blockedUsers/${right}`).get(),
    db.doc(`users/${right}/blockedUsers/${left}`).get(),
  ]);
  return forward.exists || backward.exists;
}

function readTable(data: DocumentData): OnlineV2Table {
  const seats = Array.isArray(data.seats) ?
    data.seats as OnlineV2Table["seats"] :
    [];
  const memberUids = Array.isArray(data.memberUids) ?
    data.memberUids.filter((item): item is string => {
      return typeof item === "string";
    }) :
    [];
  return {
    id: typeof data.id === "string" ? data.id : "",
    game: requireGame(data.game),
    hostUid: typeof data.hostUid === "string" ? data.hostUid : "",
    status: data.status === "abandoned" ? "abandoned" : "open",
    seats,
    memberUids,
    hands: {},
    moves: [],
    winner: null,
  };
}

export const createOnlineV2TableCall = onCall(
  {region, enforceAppCheck: true},
  async (request) => {
    assertEmulator();
    const uid = requireUid(request.auth?.uid);
    const game = requireGame(request.data?.game);
    const id = getFirestore().collection("online_v2_tables").doc().id;
    const table = createOnlineV2Table(id, game, uid, Date.now());
    await getFirestore().doc(`online_v2_tables/${id}`).set(
      publicOnlineV2Table(table),
    );
    return {tableId: id};
  },
);

export const inviteOnlineV2FriendCall = onCall(
  {region, enforceAppCheck: true},
  async (request) => {
    assertEmulator();
    const uid = requireUid(request.auth?.uid);
    const tableId = requireText(request.data?.tableId, "Masa gerekli.");
    const targetUid = requireText(
      request.data?.targetUid,
      "Hedef gerekli.",
    );
    const snapshot = await getFirestore()
      .doc(`online_v2_tables/${tableId}`)
      .get();
    if (!snapshot.exists) {
      throw new HttpsError("not-found", "Masa bulunamadı.");
    }
    const table = readTable(snapshot.data() ?? {});
    if (table.hostUid !== uid) {
      throw new HttpsError("permission-denied", "Masayı kuran davet eder.");
    }
    try {
      assertCanInvite({
        areFriends: await areFriends(uid, targetUid),
        blocked: await eitherBlocked(uid, targetUid),
      });
    } catch (error) {
      if (!(error instanceof Error)) {
        throw error;
      }
      throw new HttpsError(
        "permission-denied",
        "Yalnızca engeli olmayan arkadaş davet edilebilir.",
      );
    }
    const inviteId = getFirestore().collection("online_v2_invites").doc().id;
    const invite: OnlineV2Invite = {
      senderUid: uid,
      targetUid,
      tableId,
      status: "pending",
    };
    await getFirestore().doc(`online_v2_invites/${inviteId}`).set(invite);
    return {inviteId};
  },
);

export const acceptOnlineV2InviteCall = onCall(
  {region, enforceAppCheck: true},
  async (request) => {
    assertEmulator();
    const uid = requireUid(request.auth?.uid);
    const inviteId = requireText(request.data?.inviteId, "Davet gerekli.");
    const db = getFirestore();
    await db.runTransaction(async (transaction) => {
      const inviteRef = db.doc(`online_v2_invites/${inviteId}`);
      const inviteSnap = await transaction.get(inviteRef);
      if (!inviteSnap.exists) {
        throw new HttpsError("not-found", "Davet bulunamadı.");
      }
      const invite = inviteSnap.data() as OnlineV2Invite;
      const tableRef = db.doc(`online_v2_tables/${invite.tableId}`);
      const tableSnap = await transaction.get(tableRef);
      if (!tableSnap.exists) {
        throw new HttpsError("not-found", "Masa bulunamadı.");
      }
      const next = acceptOnlineV2Invite(
        readTable(tableSnap.data() ?? {}),
        invite,
        uid,
        Date.now(),
      );
      transaction.set(tableRef, publicOnlineV2Table(next));
      transaction.set(inviteRef, {...invite, status: "accepted"});
    });
    return {ok: true};
  },
);

export const leaveOnlineV2TableCall = onCall(
  {region, enforceAppCheck: true},
  async (request) => {
    assertEmulator();
    const uid = requireUid(request.auth?.uid);
    const tableId = requireText(request.data?.tableId, "Masa gerekli.");
    const ref = getFirestore().doc(`online_v2_tables/${tableId}`);
    await getFirestore().runTransaction(async (transaction) => {
      const snapshot = await transaction.get(ref);
      if (!snapshot.exists) {
        throw new HttpsError("not-found", "Masa bulunamadı.");
      }
      const next = leaveOnlineV2Table(
        readTable(snapshot.data() ?? {}),
        uid,
      );
      transaction.set(ref, publicOnlineV2Table(next));
    });
    return {ok: true};
  },
);

export const heartbeatOnlineV2TableCall = onCall(
  {region, enforceAppCheck: true},
  async (request) => {
    assertEmulator();
    const uid = requireUid(request.auth?.uid);
    const tableId = requireText(request.data?.tableId, "Masa gerekli.");
    const ref = getFirestore().doc(`online_v2_tables/${tableId}`);
    await getFirestore().runTransaction(async (transaction) => {
      const snapshot = await transaction.get(ref);
      if (!snapshot.exists) {
        throw new HttpsError("not-found", "Masa bulunamadı.");
      }
      const next = heartbeatOnlineV2Table(
        readTable(snapshot.data() ?? {}),
        uid,
        Date.now(),
      );
      transaction.set(ref, publicOnlineV2Table(next));
    });
    return {ok: true};
  },
);

export const submitOnlineV2MoveCall = onCall(
  {region, enforceAppCheck: true},
  async (request) => {
    assertEmulator();
    const uid = requireUid(request.auth?.uid);
    const tableId = requireText(request.data?.tableId, "Masa gerekli.");
    const moveId = requireText(request.data?.moveId, "Hamle kimliği gerekli.");
    const db = getFirestore();
    const tableRef = db.doc(`online_v2_tables/${tableId}`);
    const moveRef = tableRef.collection("moves").doc(moveId);
    const outcome = await db.runTransaction(async (transaction) => {
      const [tableSnap, moveSnap] = await Promise.all([
        transaction.get(tableRef),
        transaction.get(moveRef),
      ]);
      if (!tableSnap.exists) {
        throw new HttpsError("not-found", "Masa bulunamadı.");
      }
      const table = readTable(tableSnap.data() ?? {});
      if (moveSnap.exists) {
        return moveSnap.data();
      }
      let rejected;
      try {
        rejected = rejectOnlineV2Move(table, uid, moveId);
      } catch (error) {
        if (error instanceof HttpsError) {
          throw error;
        }
        throw new HttpsError(
          "permission-denied",
          "Bu masada hamle sırası sende değil.",
        );
      }
      transaction.set(moveRef, rejected.move);
      return rejected.move;
    });
    throw new HttpsError(
      "failed-precondition",
      "Çok oyunculu hamle motoru bu denemede bağlı değil.",
      outcome,
    );
  },
);
