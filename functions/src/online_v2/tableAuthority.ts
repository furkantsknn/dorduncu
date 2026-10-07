/* eslint-disable require-jsdoc */

export const onlineV2TurnTimeoutMs = 45_000;

export type OnlineV2Game = "okey" | "okey101" | "batak" | "tavla";

export interface OnlineV2Seat {
  uid: string | null;
  connected: boolean;
  left: boolean;
  lastSeenMs: number;
}

export interface OnlineV2Invite {
  senderUid: string;
  targetUid: string;
  tableId: string;
  status: "pending" | "accepted";
}

export interface OnlineV2Move {
  id: string;
  seat: number;
  result: "rejected";
  reason: "engine_not_attached";
}

export interface OnlineV2Table {
  id: string;
  game: OnlineV2Game;
  hostUid: string;
  status: "open" | "abandoned";
  seats: OnlineV2Seat[];
  memberUids: string[];
  hands: Record<string, string[]>;
  moves: OnlineV2Move[];
  winner: null;
}

const games = new Set<OnlineV2Game>([
  "okey",
  "okey101",
  "batak",
  "tavla",
]);

export function createOnlineV2Table(
  id: string,
  game: OnlineV2Game,
  hostUid: string,
  nowMs: number,
): OnlineV2Table {
  if (!games.has(game) || hostUid.length === 0) {
    throw new Error("invalid_table");
  }
  const count = game === "tavla" ? 2 : 4;
  const seats = Array.from({length: count}, (_, index) => ({
    uid: index === 0 ? hostUid : null,
    connected: index === 0,
    left: false,
    lastSeenMs: nowMs,
  }));
  return {
    id,
    game,
    hostUid,
    status: "open",
    seats,
    memberUids: [hostUid],
    hands: {},
    moves: [],
    winner: null,
  };
}

export function publicOnlineV2Table(
  table: OnlineV2Table,
): Record<string, unknown> {
  return {
    id: table.id,
    game: table.game,
    hostUid: table.hostUid,
    status: table.status,
    memberUids: table.memberUids,
    winner: table.winner,
    seats: table.seats.map((seat) => ({
      uid: seat.uid,
      connected: seat.connected,
      left: seat.left,
      lastSeenMs: seat.lastSeenMs,
    })),
  };
}

export function assertCanInvite(input: {
  areFriends: boolean;
  blocked: boolean;
}): void {
  if (!input.areFriends || input.blocked) {
    throw new Error("invite_blocked");
  }
}

export function acceptOnlineV2Invite(
  table: OnlineV2Table,
  invite: OnlineV2Invite,
  uid: string,
  nowMs: number,
): OnlineV2Table {
  if (invite.targetUid !== uid || invite.tableId !== table.id) {
    throw new Error("not_invite_target");
  }
  if (invite.status !== "pending" || table.status !== "open") {
    throw new Error("invite_closed");
  }
  if (table.memberUids.includes(uid)) {
    return table;
  }
  const empty = table.seats.findIndex((seat) => seat.uid === null);
  if (empty < 0) {
    throw new Error("table_full");
  }
  const seats = table.seats.map((seat, index) => {
    if (index !== empty) {
      return seat;
    }
    return {...seat, uid, connected: true, lastSeenMs: nowMs};
  });
  return {
    ...table,
    seats,
    memberUids: [...table.memberUids, uid],
    winner: null,
  };
}

export function leaveOnlineV2Table(
  table: OnlineV2Table,
  uid: string,
): OnlineV2Table {
  const index = table.seats.findIndex((seat) => seat.uid === uid);
  if (index < 0) {
    throw new Error("not_a_member");
  }
  if (table.status !== "open") {
    const seats = table.seats.map((seat, seatIndex) => {
      return seatIndex === index ? {...seat, left: true} : seat;
    });
    return {...table, seats, winner: null};
  }
  const seats = table.seats.map((seat, seatIndex) => {
    if (seatIndex !== index) {
      return seat;
    }
    return {...seat, uid: null, connected: false, left: false};
  });
  return {
    ...table,
    seats,
    memberUids: table.memberUids.filter((member) => member !== uid),
    status: uid === table.hostUid ? "abandoned" : "open",
    winner: null,
  };
}

export function heartbeatOnlineV2Table(
  table: OnlineV2Table,
  uid: string,
  nowMs: number,
): OnlineV2Table {
  const index = table.seats.findIndex((seat) => seat.uid === uid);
  if (index < 0) {
    throw new Error("not_a_member");
  }
  const seats = table.seats.map((seat, seatIndex) => {
    if (seatIndex !== index) {
      return seat;
    }
    return {...seat, connected: true, lastSeenMs: nowMs};
  });
  return {...table, seats, winner: null};
}

export function rejectOnlineV2Move(
  table: OnlineV2Table,
  uid: string,
  moveId: string,
): {table: OnlineV2Table; move: OnlineV2Move} {
  const existing = table.moves.find((move) => move.id === moveId);
  if (existing) {
    return {table, move: existing};
  }
  const seat = table.seats.findIndex((item) => {
    return item.uid === uid && !item.left;
  });
  if (seat < 0) {
    throw new Error("not_a_member");
  }
  const move: OnlineV2Move = {
    id: moveId,
    seat,
    result: "rejected",
    reason: "engine_not_attached",
  };
  return {
    table: {...table, moves: [...table.moves, move], winner: null},
    move,
  };
}

export function sweepOnlineV2Lobby(
  table: OnlineV2Table,
  nowMs: number,
): OnlineV2Table {
  if (table.status !== "open") {
    return {...table, winner: null};
  }
  let next = table;
  for (const seat of table.seats) {
    if (seat.uid === null || seat.connected) {
      continue;
    }
    const stale = nowMs - seat.lastSeenMs > onlineV2TurnTimeoutMs;
    if (stale && seat.uid !== null) {
      next = leaveOnlineV2Table(next, seat.uid);
    }
  }
  return {...next, winner: null};
}
