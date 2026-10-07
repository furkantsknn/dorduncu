/* eslint-disable require-jsdoc */
import {
  acceptOnlineV2Invite,
  assertCanInvite,
  createOnlineV2Table,
  leaveOnlineV2Table,
  publicOnlineV2Table,
  rejectOnlineV2Move,
  sweepOnlineV2Lobby,
} from "./tableAuthority";

function check(condition: boolean, message: string): void {
  if (!condition) {
    throw new Error(message);
  }
}

const table = createOnlineV2Table("t1", "okey", "host", 1_000);
table.hands.host = ["hidden-tile"];
const published = JSON.stringify(publicOnlineV2Table(table));
check(!published.includes("hidden-tile"), "public table leaked a hand");
check(!published.includes("hands"), "public table named the hand field");
check(table.winner === null, "new table has a winner");

let blocked = false;
try {
  assertCanInvite({areFriends: true, blocked: true});
  blocked = true;
} catch (error) {
  check(error instanceof Error, "block error");
}
check(!blocked, "blocked invite was allowed");

let strangerJoined = false;
try {
  acceptOnlineV2Invite(
    table,
    {
      senderUid: "host",
      targetUid: "friend",
      tableId: "t1",
      status: "pending",
    },
    "stranger",
    2_000,
  );
  strangerJoined = true;
} catch (error) {
  check(
    error instanceof Error && error.message === "not_invite_target",
    "wrong invite error",
  );
}
check(!strangerJoined, "stranger joined an invite");

const joined = acceptOnlineV2Invite(
  table,
  {
    senderUid: "host",
    targetUid: "friend",
    tableId: "t1",
    status: "pending",
  },
  "friend",
  2_000,
);
check(joined.memberUids.includes("friend"), "target did not join");

const left = leaveOnlineV2Table(joined, "friend");
check(!left.memberUids.includes("friend"), "seat stayed after leave");
check(left.winner === null, "leave wrote a winner");

let outsider = false;
try {
  rejectOnlineV2Move(joined, "outsider", "m1");
  outsider = true;
} catch (error) {
  check(
    error instanceof Error && error.message === "not_a_member",
    "outsider error",
  );
}
check(!outsider, "outsider move was stored");

const first = rejectOnlineV2Move(joined, "friend", "m1");
const second = rejectOnlineV2Move(first.table, "friend", "m1");
check(first.table.moves.length === 1, "first move was not stored once");
check(second.table.moves.length === 1, "duplicate move was applied again");
check(second.move.reason === "engine_not_attached", "move resolved a game");
check(second.table.winner === null, "rejected move wrote a winner");

const quiet = {
  ...joined,
  seats: joined.seats.map((seat) => {
    return seat.uid === "friend" ?
      {...seat, connected: false, lastSeenMs: 1_000} :
      seat;
  }),
};
const swept = sweepOnlineV2Lobby(quiet, 1_000 + 45_001);
check(!swept.memberUids.includes("friend"), "stale seat stayed");
check(swept.winner === null, "timeout wrote a winner");

console.log("online v2 authority checks passed");
