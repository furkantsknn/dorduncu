const assert = require("node:assert/strict");
const test = require("node:test");

const {
  exactGenerationDeleteOptions,
  runVerificationCleanupAttempt,
  scanVerificationCleanupPages,
} = require("../lib/users/verificationCleanupPolicy.js");

test("Storage deletion is pinned to the observed generation", () => {
  assert.deepEqual(exactGenerationDeleteOptions(" 42 "), {
    ignoreNotFound: true,
    ifGenerationMatch: "42",
  });
  assert.throws(() => exactGenerationDeleteOptions(""));
});

function records(count) {
  return Array.from({length: count}, (_, index) => ({
    id: String(index).padStart(4, "0"),
    cleaned: false,
  }));
}

async function scan(items, alreadyCleaned = 0) {
  for (let index = 0; index < alreadyCleaned; index += 1) {
    items[index].cleaned = true;
  }
  return scanVerificationCleanupPages(
    async (cursor) => {
      const start = cursor == null ? 0 :
        items.findIndex((item) => item.id === cursor) + 1;
      const page = items.slice(start, start + 100);
      return {
        records: page,
        lastId: page.length === 0 ? null : page.at(-1).id,
      };
    },
    async (item) => {
      if (item.cleaned) return false;
      item.cleaned = true;
      return true;
    },
  );
}

for (const count of [0, 100, 101, 250]) {
  test(`document-id pagination scans ${count} records`, async () => {
    const result = await scan(records(count));
    assert.deepEqual(result, {
      scanned: count,
      succeeded: count,
      failed: 0,
    });
  });
}

test("an already cleaned first page does not hide the next page", async () => {
  const result = await scan(records(250), 100);
  assert.equal(result.scanned, 250);
  assert.equal(result.succeeded, 150);
});

function cleanupFixture() {
  const state = {
    submissionId: "old-submission",
    status: "rejected",
    path: "verification_documents/u/old.jpg",
    documentsDeletedAt: null,
    deletes: 0,
    prepared: true,
  };
  const plan = {
    requestId: "u",
    submissionId: "old-submission",
    operationId: "operation-1",
    objects: [{
      field: "identityFrontPath",
      path: state.path,
      generation: "10",
    }],
  };
  const dependencies = {
    prepare: async () => state.prepared ? plan : null,
    deleteObject: async () => {
      state.deletes += 1;
    },
    complete: async (candidate) => {
      if (
        state.submissionId !== candidate.submissionId ||
        state.status !== "rejected" ||
        state.path !== candidate.objects[0].path
      ) {
        return false;
      }
      state.documentsDeletedAt = "now";
      state.prepared = false;
      return true;
    },
    failed: async () => {},
  };
  return {state, plan, dependencies};
}

test("a new submission during deletion keeps its path and marker", async () => {
  const fixture = cleanupFixture();
  fixture.dependencies.deleteObject = async () => {
    fixture.state.deletes += 1;
    fixture.state.submissionId = "new-submission";
    fixture.state.status = "pending";
    fixture.state.path = "verification_documents/u/new.jpg";
  };
  const completed = await runVerificationCleanupAttempt(
    fixture.dependencies,
  );
  assert.equal(completed, false);
  assert.equal(fixture.state.path, "verification_documents/u/new.jpg");
  assert.equal(fixture.state.documentsDeletedAt, null);
});

test("a concurrent approval prevents stale cleanup completion", async () => {
  const fixture = cleanupFixture();
  fixture.dependencies.deleteObject = async () => {
    fixture.state.status = "approved";
  };
  assert.equal(
    await runVerificationCleanupAttempt(fixture.dependencies),
    false,
  );
  assert.equal(fixture.state.documentsDeletedAt, null);
});

test("delete failure retries safely and repeated completion is idempotent", async () => {
  const fixture = cleanupFixture();
  let fail = true;
  let failures = 0;
  fixture.dependencies.deleteObject = async () => {
    if (fail) throw new Error("storage unavailable");
    fixture.state.deletes += 1;
  };
  fixture.dependencies.failed = async () => {
    failures += 1;
  };

  assert.equal(
    await runVerificationCleanupAttempt(fixture.dependencies),
    false,
  );
  assert.equal(failures, 1);
  assert.equal(fixture.state.documentsDeletedAt, null);

  fail = false;
  assert.equal(
    await runVerificationCleanupAttempt(fixture.dependencies),
    true,
  );
  assert.equal(fixture.state.documentsDeletedAt, "now");
  assert.equal(
    await runVerificationCleanupAttempt(fixture.dependencies),
    false,
  );
});

test("one record failure does not block later records", async () => {
  const items = records(101);
  const result = await scanVerificationCleanupPages(
    async (cursor) => {
      const start = cursor == null ? 0 :
        items.findIndex((item) => item.id === cursor) + 1;
      const page = items.slice(start, start + 100);
      return {
        records: page,
        lastId: page.length === 0 ? null : page.at(-1).id,
      };
    },
    async (item) => {
      if (item.id === "0001") throw new Error("record failure");
      return true;
    },
  );
  assert.deepEqual(result, {scanned: 101, succeeded: 100, failed: 1});
});
