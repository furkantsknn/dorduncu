import {readFileSync} from "node:fs";
import {after, before, describe, it} from "node:test";
import assert from "node:assert/strict";
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from "@firebase/rules-unit-testing";
import {deleteDoc, doc, getDoc, setDoc} from "firebase/firestore";
import {deleteObject, getBytes, ref, uploadBytes} from "firebase/storage";

const [firestoreHost, firestorePort] =
  (process.env.FIRESTORE_EMULATOR_HOST ?? "127.0.0.1:8080").split(":");
const [storageHost, storagePort] =
  (process.env.FIREBASE_STORAGE_EMULATOR_HOST ?? "127.0.0.1:9199").split(":");

describe("account deletion storage rules", () => {
  let env;
  before(async () => {
    env = await initializeTestEnvironment({
      projectId: "demo-account-deletion-storage",
      firestore: {
        host: firestoreHost,
        port: Number(firestorePort),
        rules: readFileSync(process.env.RULES_FILE ?? "firestore.rules", "utf8"),
      },
      storage: {
        host: storageHost,
        port: Number(storagePort),
        rules: readFileSync(process.env.STORAGE_RULES_FILE ?? "storage.rules", "utf8"),
      },
    });
  });
  after(async () => env.cleanup());

  async function seedStatus(uid, accountStatus) {
    await env.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), `users/${uid}`), {
        accountStatus,
      });
    });
  }

  async function assertBothUploads(uid, succeeds, suffix) {
    const owner = env.authenticatedContext(uid);
    const expectation = succeeds ? assertSucceeds : assertFails;
    await expectation(uploadBytes(
      ref(owner.storage(), `profile_photos/${uid}/profile_${suffix}.jpg`),
      new Uint8Array([1]), {contentType: "image/jpeg"},
    ));
    await expectation(uploadBytes(
      ref(
        owner.storage(),
        `verification_documents/${uid}/identity_front_${suffix}.jpg`,
      ),
      new Uint8Array([2]), {contentType: "image/jpeg"},
    ));
  }

  it("allows pending and active onboarding uploads but not a missing profile", async () => {
    await assertBothUploads("missing-user", false, "missing");
    await seedStatus("pending-user", "pendingProfile");
    await assertBothUploads("pending-user", true, "pending");
    await seedStatus("active-user", "active");
    await assertBothUploads("active-user", true, "active");
  });

  it("rejects deletion, suspension, blocking, and a deleted profile", async () => {
    for (const status of ["deletionRequested", "suspended", "blocked"]) {
      const uid = `${status}-user`;
      await seedStatus(uid, status);
      await assertBothUploads(uid, false, status);
    }
    const uid = "deleted-profile-user";
    await seedStatus(uid, "active");
    await assertBothUploads(uid, true, "before-delete");
    await env.withSecurityRulesDisabled(async (context) => {
      await deleteDoc(doc(context.firestore(), `users/${uid}`));
    });
    await assertBothUploads(uid, false, "after-delete");
    assert.ok(true);
  });

  it("allows private support images only to the owner and support roles", async () => {
    const uid = "support-owner";
    await seedStatus(uid, "active");
    const owner = env.authenticatedContext(uid);
    const outsider = env.authenticatedContext("outsider");
    const support = env.authenticatedContext("support-agent", {
      role: "support_officer",
    });
    const imageRef = ref(
      owner.storage(),
      `support_attachments/${uid}/draft-1/evidence.jpg`,
    );

    await assertSucceeds(uploadBytes(
      imageRef,
      new Uint8Array([1]),
      {contentType: "image/jpeg"},
    ));
    await assertSucceeds(getBytes(ref(
      support.storage(),
      `support_attachments/${uid}/draft-1/evidence.jpg`,
    )));
    await assertFails(getBytes(ref(
      outsider.storage(),
      `support_attachments/${uid}/draft-1/evidence.jpg`,
    )));
    await assertFails(uploadBytes(
      ref(owner.storage(), `support_attachments/${uid}/draft-1/evidence.txt`),
      new Uint8Array([1]),
      {contentType: "text/plain"},
    ));
    await assertSucceeds(deleteObject(imageRef));
  });

  it("denies moderation evidence to normal users and reporters", async () => {
    const evidencePath = "moderation_evidence/profile_images/evidence-1";
    await env.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), "moderation_evidence/evidence-1"), {
        kind: "profile_image",
        targetUid: "reported-user",
      });
      await setDoc(doc(context.firestore(), "moderation_report_evidence/report-1"), {
        reporterUid: "reporter-user",
        evidence: {message: {text: "private evidence"}},
      });
      await uploadBytes(
        ref(context.storage(), evidencePath),
        new Uint8Array([1, 2, 3]),
        {contentType: "image/jpeg"},
      );
    });
    for (const uid of ["normal-user", "reporter-user", "reported-user"]) {
      const context = env.authenticatedContext(uid);
      await assertFails(getDoc(doc(
        context.firestore(),
        "moderation_evidence/evidence-1",
      )));
      await assertFails(getDoc(doc(
        context.firestore(),
        "moderation_report_evidence/report-1",
      )));
      await assertFails(getBytes(ref(context.storage(), evidencePath)));
    }
  });

  it("rejects direct support creation and forged moderation fields", async () => {
    const reporter = env.authenticatedContext("reporter-user");
    await assertFails(setDoc(doc(reporter.firestore(), "support_requests/forged"), {
      userId: "reporter-user",
      category: "message_report",
      status: "new",
      evidenceSnapshot: {message: {text: "forged"}},
      moderationProfileTarget: {
        path: "profile_photos/victim/current.jpg",
        generation: "1",
      },
    }));
    await assertFails(setDoc(doc(
      reporter.firestore(),
      "moderation_report_evidence/forged",
    ), {evidence: {message: {text: "forged"}}}));
  });
});
