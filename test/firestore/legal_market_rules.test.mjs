import { readFileSync } from "node:fs";
import { describe, it, before, after, beforeEach } from "node:test";
import assert from "node:assert/strict";
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from "@firebase/rules-unit-testing";
import {
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  query,
  serverTimestamp,
  setDoc,
  updateDoc,
  where,
  writeBatch,
} from "firebase/firestore";

const emulator = process.env.FIRESTORE_EMULATOR_HOST ?? "";
const [host, portText] = emulator.split(":");
const port = Number(portText);

const ownerUid = "owner-user";
const otherUid = "other-user";
const onboardingCodes = ["terms_of_use", "community_rules", "age_declaration"];

function acceptancePayload(uid, code, version) {
  return {
    userId: uid,
    documentCode: code,
    version,
    acceptedAt: serverTimestamp(),
    locale: "tr",
    source: "onboarding/login",
    active: true,
  };
}

function profilePayload(uid, phone, pending = false) {
  return {
    uid, ad: "Ada", soyad: "Yilmaz", profilAdi: "Ada Yilmaz",
    telefon: phone, dogumTarihi: new Date("2000-01-01T00:00:00Z"), yas: 26,
    cinsiyet: "Kadin", sehir: "Istanbul", ilce: "Kadikoy", hakkimda: "",
    profilFotografi: "", avatarUrl: "", latitude: 0, longitude: 0, puan: 0,
    plus: false, accountStatus: pending ? "pendingProfile" : "active",
    lastLoginAt: serverTimestamp(),
    lastLoginPlatform: "android", lastLoginAppVersion: "1.0.0",
    lastDeviceId: "device", verified: false, verificationStatus: "none",
    verificationSkipped: true, oyunlar: [], gameIds: [], gameSkills: {},
    onboardingCompleted: !pending, olusturmaTarihi: serverTimestamp(),
    guncellemeTarihi: serverTimestamp(),
  };
}

/** Mirrors LegalService.recordOnboardingAcceptances. */
async function recordOnboardingAcceptances(db, uid, version) {
  const acceptances = collection(db, `users/${uid}/legal_acceptances`);
  for (const code of onboardingCodes) {
    const documentId = `${code}_${version}`;
    const currentRef = doc(acceptances, documentId);
    const current = await getDoc(currentRef);
    if (current.exists()) {
      continue;
    }
    const previous = await getDocs(
      query(acceptances, where("documentCode", "==", code)),
    );
    const batch = writeBatch(db);
    for (const old of previous.docs) {
      if (old.id === documentId || old.data().active !== true) {
        continue;
      }
      batch.update(old.ref, { active: false });
    }
    batch.set(currentRef, acceptancePayload(uid, code, version));
    await batch.commit();
  }
}

describe("legal acceptance and market rules", () => {
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

  beforeEach(async () => {
    await testEnv.clearFirestore();
  });

  async function adminRead(path) {
    let data;
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const snap = await getDoc(doc(context.firestore(), path));
      data = snap.exists() ? snap.data() : undefined;
    });
    return data;
  }

  async function seed(path, data) {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), path), data);
    });
  }

  it("records the three onboarding acceptances for the signed-in user", async () => {
    const owner = testEnv.authenticatedContext(ownerUid).firestore();
    await assertSucceeds(recordOnboardingAcceptances(owner, ownerUid, "1.0.0"));

    for (const code of onboardingCodes) {
      const data = await adminRead(
        `users/${ownerUid}/legal_acceptances/${code}_1.0.0`,
      );
      assert.ok(data, `${code} missing`);
      assert.equal(data.userId, ownerUid);
      assert.equal(data.documentCode, code);
      assert.equal(data.version, "1.0.0");
      assert.equal(data.locale, "tr");
      assert.equal(data.source, "onboarding/login");
      assert.equal(data.active, true);
      assert.equal(typeof data.acceptedAt?.toMillis, "function");
    }
  });

  it("does not rewrite the same version on a second login", async () => {
    const owner = testEnv.authenticatedContext(ownerUid).firestore();
    await recordOnboardingAcceptances(owner, ownerUid, "1.0.0");
    const first = await adminRead(
      `users/${ownerUid}/legal_acceptances/terms_of_use_1.0.0`,
    );

    await assertSucceeds(recordOnboardingAcceptances(owner, ownerUid, "1.0.0"));
    const second = await adminRead(
      `users/${ownerUid}/legal_acceptances/terms_of_use_1.0.0`,
    );
    assert.equal(
      second.acceptedAt.toMillis(),
      first.acceptedAt.toMillis(),
    );
  });

  it("blocks profile creation until all three current records exist", async () => {
    const phone = "+905551112233";
    const auth = {phone_number: phone};
    const owner = testEnv.authenticatedContext(ownerUid, auth).firestore();
    await assertFails(setDoc(
      doc(owner, `users/${ownerUid}`),
      profilePayload(ownerUid, phone),
    ));
    await setDoc(
      doc(owner, `users/${ownerUid}/legal_acceptances/terms_of_use_1.0.0`),
      acceptancePayload(ownerUid, "terms_of_use", "1.0.0"),
    );
    await assertFails(setDoc(
      doc(owner, `users/${ownerUid}`),
      profilePayload(ownerUid, phone),
    ));
    await recordOnboardingAcceptances(owner, ownerUid, "1.0.0");
    await assertSucceeds(setDoc(
      doc(owner, `users/${ownerUid}`),
      profilePayload(ownerUid, phone),
    ));
  });

  it("creates, retries, and finalizes a pending onboarding profile", async () => {
    const uid = "pending-profile-owner";
    const phone = "+905551112244";
    const owner = testEnv.authenticatedContext(
      uid, {phone_number: phone},
    ).firestore();
    await recordOnboardingAcceptances(owner, uid, "1.0.0");
    const reference = doc(owner, `users/${uid}`);
    await assertSucceeds(setDoc(reference, profilePayload(uid, phone, true)));
    await assertSucceeds(setDoc(reference, profilePayload(uid, phone, true)));
    await assertSucceeds(updateDoc(reference, {
      profilFotografi: "https://example.invalid/profile.jpg",
      avatarUrl: "",
      accountStatus: "active",
      onboardingCompleted: true,
      verificationStatus: "pending",
      verificationSkipped: false,
      guncellemeTarihi: serverTimestamp(),
    }));
    await assertFails(updateDoc(reference, {
      accountStatus: "pendingProfile",
      onboardingCompleted: false,
    }));
  });

  it("enforces the adult birth-date boundary in rules, not only the UI", async () => {
    const phone = "+905551112233";
    const owner = testEnv.authenticatedContext(
      ownerUid,
      {phone_number: phone},
    ).firestore();
    await recordOnboardingAcceptances(owner, ownerUid, "1.0.0");
    const underage = profilePayload(ownerUid, phone);
    underage.dogumTarihi = new Date();
    underage.yas = 99;
    await assertFails(setDoc(doc(owner, `users/${ownerUid}`), underage));

    const adult = profilePayload(ownerUid, phone);
    adult.yas = 17;
    await assertSucceeds(setDoc(doc(owner, `users/${ownerUid}`), adult));
  });

  it("uses the exact calendar birthday boundary and accepts leap-day adults", async () => {
    const uid = "calendar-age-user";
    const phone = "+905551112244";
    const owner = testEnv.authenticatedContext(uid, {phone_number: phone})
      .firestore();
    await recordOnboardingAcceptances(owner, uid, "1.0.0");
    const now = new Date();
    const exactBirthday = new Date(Date.UTC(
      now.getUTCFullYear() - 18,
      now.getUTCMonth(),
      now.getUTCDate(),
    ));
    const dayBeforeBirthday = new Date(exactBirthday);
    dayBeforeBirthday.setUTCDate(dayBeforeBirthday.getUTCDate() + 1);
    const dayAfterBirthday = new Date(exactBirthday);
    dayAfterBirthday.setUTCDate(dayAfterBirthday.getUTCDate() - 1);

    const underage = profilePayload(uid, phone);
    underage.dogumTarihi = dayBeforeBirthday;
    underage.yas = 99;
    await assertFails(setDoc(doc(owner, `users/${uid}`), underage));

    const exact = profilePayload(uid, phone);
    exact.dogumTarihi = exactBirthday;
    exact.yas = 0;
    await assertSucceeds(setDoc(doc(owner, `users/${uid}`), exact));
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await deleteDoc(doc(context.firestore(), `users/${uid}`));
    });

    const after = profilePayload(uid, phone);
    after.dogumTarihi = dayAfterBirthday;
    after.yas = -1;
    await assertSucceeds(setDoc(doc(owner, `users/${uid}`), after));

    const leapUid = "leap-day-user";
    const leapPhone = "+905551112255";
    const leapOwner = testEnv.authenticatedContext(
      leapUid, {phone_number: leapPhone},
    ).firestore();
    await recordOnboardingAcceptances(leapOwner, leapUid, "1.0.0");
    const leap = profilePayload(leapUid, leapPhone);
    leap.dogumTarihi = new Date("2008-02-29T00:00:00Z");
    leap.yas = 0;
    await assertSucceeds(setDoc(doc(leapOwner, `users/${leapUid}`), leap));
  });

  it("keeps the old version and marks it inactive when a new version is accepted", async () => {
    const owner = testEnv.authenticatedContext(ownerUid).firestore();
    await recordOnboardingAcceptances(owner, ownerUid, "1.0.0");
    await assertSucceeds(recordOnboardingAcceptances(owner, ownerUid, "1.1.0"));

    const old = await adminRead(
      `users/${ownerUid}/legal_acceptances/terms_of_use_1.0.0`,
    );
    const current = await adminRead(
      `users/${ownerUid}/legal_acceptances/terms_of_use_1.1.0`,
    );
    assert.equal(old.active, false);
    assert.equal(old.version, "1.0.0");
    assert.equal(current.active, true);
  });

  it("denies writing an acceptance for another user", async () => {
    const other = testEnv.authenticatedContext(otherUid).firestore();
    await assertFails(
      setDoc(
        doc(other, `users/${ownerUid}/legal_acceptances/terms_of_use_1.0.0`),
        acceptancePayload(ownerUid, "terms_of_use", "1.0.0"),
      ),
    );
    await assertFails(
      setDoc(
        doc(other, `users/${ownerUid}/legal_acceptances/terms_of_use_1.0.0`),
        acceptancePayload(otherUid, "terms_of_use", "1.0.0"),
      ),
    );
  });

  it("denies unauthenticated acceptance writes", async () => {
    const anon = testEnv.unauthenticatedContext().firestore();
    await assertFails(
      setDoc(
        doc(anon, `users/${ownerUid}/legal_acceptances/terms_of_use_1.0.0`),
        acceptancePayload(ownerUid, "terms_of_use", "1.0.0"),
      ),
    );
  });

  it("requires the server timestamp and the fixed field list", async () => {
    const owner = testEnv.authenticatedContext(ownerUid).firestore();
    const path = `users/${ownerUid}/legal_acceptances/terms_of_use_1.0.0`;

    await assertFails(
      setDoc(doc(owner, path), {
        ...acceptancePayload(ownerUid, "terms_of_use", "1.0.0"),
        acceptedAt: new Date("2020-01-01T00:00:00Z"),
      }),
    );
    await assertFails(
      setDoc(doc(owner, path), {
        ...acceptancePayload(ownerUid, "terms_of_use", "1.0.0"),
        extra: true,
      }),
    );
    const { locale: _locale, ...withoutLocale } = acceptancePayload(
      ownerUid,
      "terms_of_use",
      "1.0.0",
    );
    assert.equal(_locale, "tr");
    await assertFails(setDoc(doc(owner, path), withoutLocale));
    await assertFails(
      setDoc(doc(owner, path), {
        ...acceptancePayload(ownerUid, "terms_of_use", "1.0.0"),
        active: false,
      }),
    );
  });

  it("requires the document id to match code and version", async () => {
    const owner = testEnv.authenticatedContext(ownerUid).firestore();
    await assertFails(
      setDoc(
        doc(owner, `users/${ownerUid}/legal_acceptances/terms_of_use_2.0.0`),
        acceptancePayload(ownerUid, "terms_of_use", "1.0.0"),
      ),
    );
    await assertFails(
      setDoc(
        doc(owner, `users/${ownerUid}/legal_acceptances/terms_of_use_v1`),
        acceptancePayload(ownerUid, "terms_of_use", "v1"),
      ),
    );
    await assertFails(
      setDoc(
        doc(owner, `users/${ownerUid}/legal_acceptances/marketing_1.0.0`),
        acceptancePayload(ownerUid, "marketing", "1.0.0"),
      ),
    );
  });

  it("denies changing or deleting acceptance history", async () => {
    const owner = testEnv.authenticatedContext(ownerUid).firestore();
    await recordOnboardingAcceptances(owner, ownerUid, "1.0.0");
    const path = `users/${ownerUid}/legal_acceptances/terms_of_use_1.0.0`;

    await assertFails(updateDoc(doc(owner, path), { version: "9.9.9" }));
    await assertFails(
      updateDoc(doc(owner, path), { acceptedAt: serverTimestamp() }),
    );
    await assertFails(
      updateDoc(doc(owner, path), { active: false, locale: "en" }),
    );
    await assertFails(deleteDoc(doc(owner, path)));

    await assertSucceeds(updateDoc(doc(owner, path), { active: false }));
    await assertFails(updateDoc(doc(owner, path), { active: true }));
    await assertFails(deleteDoc(doc(owner, path)));

    const other = testEnv.authenticatedContext(otherUid).firestore();
    await assertFails(getDoc(doc(other, path)));
  });

  it("keeps owned badge purchase records private to the owner and staff", async () => {
    const path = `users/${ownerUid}/owned_badges/okey`;
    await seed(path, {
      badgeId: "okey",
      purchaseTokenHash: "hash",
      googlePlayOrderId: "GPA.0000",
    });

    const owner = testEnv.authenticatedContext(ownerUid).firestore();
    const other = testEnv.authenticatedContext(otherUid).firestore();
    const moderator = testEnv
      .authenticatedContext("mod-user", { role: "moderator" })
      .firestore();

    await assertSucceeds(getDoc(doc(owner, path)));
    await assertSucceeds(getDocs(collection(owner, `users/${ownerUid}/owned_badges`)));
    await assertFails(getDoc(doc(other, path)));
    await assertFails(getDocs(collection(other, `users/${ownerUid}/owned_badges`)));
    await assertSucceeds(getDoc(doc(moderator, path)));
    await assertFails(setDoc(doc(owner, path), { badgeId: "okey" }));
    await assertFails(deleteDoc(doc(owner, path)));
  });

  it("serves public badge display from public_profiles only", async () => {
    const path = `public_profiles/${ownerUid}`;
    await seed(path, {
      marketBadges: [{ badgeId: "okey", title: "Okey" }],
    });

    const other = testEnv.authenticatedContext(otherUid).firestore();
    const owner = testEnv.authenticatedContext(ownerUid).firestore();
    const anon = testEnv.unauthenticatedContext().firestore();

    await assertSucceeds(getDoc(doc(other, path)));
    await assertFails(getDoc(doc(anon, path)));
    await assertFails(
      setDoc(doc(owner, path), {
        marketBadges: [{ badgeId: "batak", title: "Batak" }],
      }),
    );
  });

  it("limits market sales to finance staff", async () => {
    const path = "market_sales/sale-1";
    await seed(path, { userUid: ownerUid, productId: "dort_badge_okey" });

    const owner = testEnv.authenticatedContext(ownerUid).firestore();
    const finance = testEnv
      .authenticatedContext("finance-user", { role: "finance_officer" })
      .firestore();
    const moderator = testEnv
      .authenticatedContext("mod-user", { role: "moderator" })
      .firestore();

    await assertFails(getDoc(doc(owner, path)));
    await assertFails(getDoc(doc(moderator, path)));
    await assertSucceeds(getDoc(doc(finance, path)));
    await assertFails(setDoc(doc(finance, path), { productId: "x" }));
  });
});
