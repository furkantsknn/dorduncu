const assert = require("node:assert/strict");
const test = require("node:test");
const {initializeApp} = require("firebase-admin/app");
const {getFirestore, Timestamp} = require("firebase-admin/firestore");

const projectId = "dorduncu-8e599";
const authBase = "http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1";
const functionsBase = `http://127.0.0.1:5001/${projectId}/europe-west1`;
process.env.FIRESTORE_EMULATOR_HOST ||= "127.0.0.1:8080";
initializeApp({projectId});
const db = getFirestore();
const emulatorAppCheckToken = [
  Buffer.from(JSON.stringify({alg: "none"})).toString("base64url"),
  Buffer.from(JSON.stringify({app_id: "release-candidate-emulator"})).toString("base64url"),
  "",
].join(".");

async function auth(path, body) {
  const response = await fetch(`${authBase}/${path}?key=fake-api-key`, {
    method: "POST",
    headers: {"content-type": "application/json"},
    body: JSON.stringify(body),
  });
  const result = await response.json();
  assert.equal(response.ok, true, JSON.stringify(result));
  return result;
}

async function call(name, token, data, expectedStatus = 200) {
  const response = await fetch(`${functionsBase}/${name}`, {
    method: "POST",
    headers: {
      "content-type": "application/json",
      authorization: `Bearer ${token}`,
      "x-firebase-appcheck": emulatorAppCheckToken,
    },
    body: JSON.stringify({data}),
  });
  const result = await response.json();
  assert.equal(response.status, expectedStatus, `${name}: ${JSON.stringify(result)}`);
  return result;
}

async function waitFor(read, accept, label) {
  const deadline = Date.now() + 12000;
  while (Date.now() < deadline) {
    const value = await read();
    if (accept(value)) return value;
    await new Promise((resolve) => setTimeout(resolve, 250));
  }
  assert.fail(`Timed out waiting for ${label}`);
}

test("critical admin operations write and project through the emulator", async (t) => {
  const admin = await auth("accounts:signInWithPassword", {
    email: "admin@dev.dort.invalid",
    password: "Dort-Dev-Only-2026",
    returnSecureToken: true,
  });
  const suffix = Date.now().toString(36);
  const uid = `rc_user_${suffix}`;
  const supportId = `rc_support_${suffix}`;
  const verificationId = `rc_verification_${suffix}`;
  const eventId = `rc_event_${suffix}`;
  const badgeId = `rc_badge_${suffix}`;
  const userRef = db.collection("users").doc(uid);
  const publicRef = db.collection("public_profiles").doc(uid);
  const supportRef = db.collection("support_requests").doc(supportId);
  const verificationRef = db.collection("verification_requests").doc(verificationId);
  const eventRef = db.collection("events").doc(eventId);
  const badgeRef = db.collection("badge_products").doc(badgeId);

  await userRef.set({
    uid,
    profilAdi: "Release Adayı Sentetik",
    accountStatus: "active",
    role: "user",
    admin: false,
    plus: false,
    verified: false,
    oyuncuRozeti: false,
    createdAt: Timestamp.now(),
    updatedAt: Timestamp.now(),
  });
  await Promise.all([
    supportRef.set({
      userId: uid, uid, ticketId: `DST-${suffix.toUpperCase()}`,
      subject: "Release candidate support", description: "Emulator only",
      status: "new", createdAt: Timestamp.now(), updatedAt: Timestamp.now(),
    }),
    verificationRef.set({
      userId: uid, uid, displayName: "Release Adayı Sentetik",
      status: "pending", createdAt: Timestamp.now(), updatedAt: Timestamp.now(),
    }),
    eventRef.set({
      title: "Release candidate event", olusturanUid: uid, ownerId: uid,
      status: "active", durum: "active",
      eventDate: Timestamp.fromMillis(Date.now() + 86400000),
      createdAt: Timestamp.now(), updatedAt: Timestamp.now(),
    }),
    badgeRef.set({
      gameId: "valorant", gameName: "Valorant", title: "RC Badge",
      active: true, createdAt: Timestamp.now(), updatedAt: Timestamp.now(),
    }),
  ]);

  await t.test("Plus, player badge and market badge reach public projections", async () => {
    await call("adminUpdateMembership", admin.idToken, {
      userId: uid, action: "plus", enabled: true, reason: "Release candidate check",
    });
    await call("adminUpdateMembership", admin.idToken, {
      userId: uid, action: "playerBadge", enabled: true, reason: "Release candidate check",
    });
    await call("adminManageUserBadge", admin.idToken, {
      targetUid: uid, badgeId, action: "grant", reason: "Release candidate check",
    });
    const privateData = (await userRef.get()).data();
    assert.equal(privateData.plusAdminGranted, true);
    assert.equal(privateData.oyuncuRozeti, true);
    const projected = await waitFor(
      async () => (await publicRef.get()).data() || {},
      (data) => data.plus === true && data.oyuncuRozeti === true &&
        Array.isArray(data.marketBadges) && data.marketBadges.some((item) => item.badgeId === badgeId || item.productId === badgeId),
      "Plus/player/market badge public projection",
    );
    assert.equal(projected.plusAdminGranted, true);
  });

  await t.test("support reply and status keep the same ticket and notify the user", async () => {
    await call("adminReplySupportRequest", admin.idToken, {
      requestId: supportId, response: "Release candidate emulator response",
    });
    let support = (await supportRef.get()).data();
    assert.equal(support.status, "answered");
    assert.equal(support.ticketId, `DST-${suffix.toUpperCase()}`);
    assert.equal((await supportRef.collection("messages").get()).size, 1);
    assert.equal((await userRef.collection("notifications").where("type", "==", "support").get()).size, 1);
    await call("adminUpdateSupportRequest", admin.idToken, {requestId: supportId, status: "closed"});
    support = (await supportRef.get()).data();
    assert.equal(support.status, "closed");
  });

  await t.test("verification decision updates user and removes pending queue item", async () => {
    const before = await db.collection("verification_requests").where("status", "==", "pending").get();
    await call("processVerification", admin.idToken, {
      requestId: verificationId, status: "revision", decisionReason: "Belge yeniden yüklenmeli",
    });
    const requestData = (await verificationRef.get()).data();
    const userData = (await userRef.get()).data();
    const after = await db.collection("verification_requests").where("status", "==", "pending").get();
    assert.equal(requestData.status, "revision");
    assert.equal(userData.verificationStatus, "revision");
    assert.equal(after.size, before.size - 1);
  });

  await t.test("event moderation changes list/detail source state", async () => {
    await call("adminUpdateEventStatus", admin.idToken, {
      eventId, status: "hidden", reason: "Release candidate check",
    });
    const event = (await eventRef.get()).data();
    assert.equal(event.status, "hidden");
    assert.equal(event.durum, "hidden");
  });

  await t.test("unauthorized callable operation is rejected", async () => {
    const user = await auth("accounts:signUp", {
      email: `rc-${suffix}@dev.dort.invalid`,
      password: "Release-Candidate-2026",
      returnSecureToken: true,
    });
    const result = await call("adminUpdateEventStatus", user.idToken, {
      eventId, status: "cancelled", reason: "Must be rejected",
    }, 403);
    assert.match(String(result.error?.status || ""), /PERMISSION_DENIED/);
    assert.equal((await eventRef.get()).data().status, "hidden");
  });

  await Promise.all([
    db.recursiveDelete(userRef),
    db.recursiveDelete(publicRef),
    db.recursiveDelete(supportRef),
    db.recursiveDelete(verificationRef),
    db.recursiveDelete(eventRef),
    db.recursiveDelete(badgeRef),
  ]);
});
