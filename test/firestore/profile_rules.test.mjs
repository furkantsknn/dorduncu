import { readFileSync } from "node:fs";
import { describe, it, before, after } from "node:test";
import assert from "node:assert/strict";
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from "@firebase/rules-unit-testing";
import {
  arrayRemove,
  arrayUnion,
  doc,
  getDoc,
  serverTimestamp,
  setDoc,
} from "firebase/firestore";

const emulator = process.env.FIRESTORE_EMULATOR_HOST ?? "";
const [host, portText] = emulator.split(":");
const port = Number(portText);

const ownerUid = "owner-user";
const otherUid = "other-user";

function baseUser() {
  return {
    uid: ownerUid,
    profilAdi: "Ada Yilmaz",
    sehir: "Istanbul",
    ilce: "Kadikoy",
    aktifSehir: "Ankara",
    plus: false,
    role: "user",
    verified: false,
    verificationStatus: "none",
    oyuncuRozeti: false,
  };
}

describe("profile text rules", () => {
  /** @type {import("@firebase/rules-unit-testing").RulesTestEnvironment} */
  let testEnv;

  before(async () => {
    assert.ok(host && port, "FIRESTORE_EMULATOR_HOST is required");
    testEnv = await initializeTestEnvironment({
      projectId: "demo-dorduncu-rules",
      firestore: {
        rules: readFileSync(process.env.RULES_FILE ?? "firestore.rules", "utf8"),
        host,
        port,
      },
    });
  });

  after(async () => {
    await testEnv.cleanup();
  });

  async function seed() {
    await testEnv.clearFirestore();
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), `users/${ownerUid}`), baseUser());
    });
  }

  async function readOwner() {
    let data;
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const snap = await getDoc(
        doc(context.firestore(), `users/${ownerUid}`),
      );
      data = snap.data();
    });
    return data;
  }

  it("lets the owner update name, city, and clear the district", async () => {
    await seed();
    const owner = testEnv.authenticatedContext(ownerUid).firestore();
    await assertSucceeds(
      setDoc(
        doc(owner, `users/${ownerUid}`),
        {
          profilAdi: "Ece Demir",
          sehir: "Bursa",
          ilce: "",
          guncellemeTarihi: new Date(),
        },
        { merge: true },
      ),
    );

    const data = await readOwner();
    assert.equal(data.profilAdi, "Ece Demir");
    assert.equal(data.sehir, "Bursa");
    assert.equal(data.ilce, "");
    assert.equal(data.aktifSehir, "Ankara");
    assert.equal(data.plus, false);
    assert.equal(data.verified, false);
    assert.equal(data.oyuncuRozeti, false);
    assert.equal(data.role, "user");
  });

  it("rejects another user", async () => {
    await seed();
    const other = testEnv.authenticatedContext(otherUid).firestore();
    await assertFails(
      setDoc(
        doc(other, `users/${ownerUid}`),
        {
          profilAdi: "Baskasi",
          sehir: "Izmir",
          ilce: "",
        },
        { merge: true },
      ),
    );
    const data = await readOwner();
    assert.equal(data.profilAdi, "Ada Yilmaz");
    assert.equal(data.sehir, "Istanbul");
  });

  it("rejects Plus, role, verification, and badge in the same request", async () => {
    await seed();
    const owner = testEnv.authenticatedContext(ownerUid).firestore();
    await assertFails(
      setDoc(
        doc(owner, `users/${ownerUid}`),
        {
          profilAdi: "Ece Demir",
          sehir: "Bursa",
          ilce: "",
          plus: true,
          role: "admin",
          verified: true,
          verificationStatus: "approved",
          oyuncuRozeti: true,
        },
        { merge: true },
      ),
    );
    const data = await readOwner();
    assert.deepEqual(
      {
        profilAdi: data.profilAdi,
        sehir: data.sehir,
        ilce: data.ilce,
        aktifSehir: data.aktifSehir,
        plus: data.plus,
        role: data.role,
        verified: data.verified,
        verificationStatus: data.verificationStatus,
        oyuncuRozeti: data.oyuncuRozeti,
      },
      {
        profilAdi: "Ada Yilmaz",
        sehir: "Istanbul",
        ilce: "Kadikoy",
        aktifSehir: "Ankara",
        plus: false,
        role: "user",
        verified: false,
        verificationStatus: "none",
        oyuncuRozeti: false,
      },
    );
  });

  for (const [field, value] of [
    ["plus", true],
    ["role", "admin"],
    ["verified", true],
    ["verificationStatus", "approved"],
    ["oyuncuRozeti", true],
  ]) {
    it(`rejects ${field} next to a valid profile edit`, async () => {
      await seed();
      const owner = testEnv.authenticatedContext(ownerUid).firestore();
      await assertFails(
        setDoc(
          doc(owner, `users/${ownerUid}`),
          { profilAdi: "Ece Demir", sehir: "Bursa", ilce: "", [field]: value },
          { merge: true },
        ),
      );
      const data = await readOwner();
      assert.equal(data[field], baseUser()[field]);
      assert.equal(data.profilAdi, "Ada Yilmaz");
    });
  }

  it("accepts the editor save shape and keeps aktifSehir", async () => {
    await seed();
    const owner = testEnv.authenticatedContext(ownerUid).firestore();
    await assertSucceeds(
      setDoc(
        doc(owner, `users/${ownerUid}`),
        {
          profilFotografi: "https://example.com/a.jpg",
          avatarUrl: "",
          oyunlar: ["Okey"],
          gameIds: ["okey"],
          gameSkills: { okey: { gameId: "okey", gameName: "Okey", level: 60 } },
          hakkimda: "Merhaba",
          profilAdi: "Ece Demir",
          sehir: "Bursa",
          ilce: "",
          guncellemeTarihi: new Date(),
        },
        { merge: true },
      ),
    );
    const data = await readOwner();
    assert.equal(data.sehir, "Bursa");
    assert.equal(data.ilce, "");
    assert.equal(data.aktifSehir, "Ankara");
  });

  it("keeps the district when the city does not change", async () => {
    await seed();
    const owner = testEnv.authenticatedContext(ownerUid).firestore();
    await assertSucceeds(
      setDoc(
        doc(owner, `users/${ownerUid}`),
        { profilAdi: "Ece Demir", sehir: "Istanbul" },
        { merge: true },
      ),
    );
    const data = await readOwner();
    assert.equal(data.ilce, "Kadikoy");
  });

  for (const [label, patch] of [
    ["one-letter name", { profilAdi: "E" }],
    ["non-string name", { profilAdi: 42 }],
    ["one-letter city", { sehir: "B" }],
    ["too-long city", { sehir: "x".repeat(41) }],
    ["non-string district", { ilce: 7 }],
  ]) {
    it(`rejects ${label}`, async () => {
      await seed();
      const owner = testEnv.authenticatedContext(ownerUid).firestore();
      await assertFails(
        setDoc(doc(owner, `users/${ownerUid}`), patch, { merge: true }),
      );
    });
  }

  it("rejects an unauthenticated write", async () => {
    await seed();
    const anon = testEnv.unauthenticatedContext().firestore();
    await assertFails(
      setDoc(
        doc(anon, `users/${ownerUid}`),
        { profilAdi: "Ece Demir" },
        { merge: true },
      ),
    );
  });

  it("lets the owner add and remove a favorite event", async () => {
    await seed();
    const owner = testEnv.authenticatedContext(ownerUid).firestore();
    await assertSucceeds(
      setDoc(
        doc(owner, `users/${ownerUid}`),
        {
          favoriEtkinlikler: arrayUnion("event-1"),
          guncellemeTarihi: serverTimestamp(),
        },
        { merge: true },
      ),
    );
    assert.deepEqual((await readOwner()).favoriEtkinlikler, ["event-1"]);
    await assertSucceeds(
      setDoc(
        doc(owner, `users/${ownerUid}`),
        {
          favoriEtkinlikler: arrayRemove("event-1"),
          guncellemeTarihi: serverTimestamp(),
        },
        { merge: true },
      ),
    );
    assert.deepEqual((await readOwner()).favoriEtkinlikler, []);

    const other = testEnv.authenticatedContext(otherUid).firestore();
    await assertFails(
      setDoc(
        doc(other, `users/${ownerUid}`),
        { favoriEtkinlikler: arrayUnion("event-2") },
        { merge: true },
      ),
    );
  });
});
