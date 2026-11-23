const test = require("node:test");
const assert = require("node:assert/strict");
const {spawnSync} = require("node:child_process");
const path = require("node:path");

// Each reviewed deployment exports a single module, without the main index's
// unrelated imports. Loading that module must initialize Admin without I/O.
for (const moduleName of [
  "notifications/processAdminNotifications",
  "notifications/processNotificationDeliveryQueue",
  "events/markEventCompleted",
  "events/getEventCreationQuotaState",
]) {
  test(`isolated cold start initializes Admin: ${moduleName}`, () => {
    const result = spawnSync(process.execPath, ["-e", `
      const assert = require('node:assert/strict');
      const admin = require('firebase-admin/app');
      assert.equal(admin.getApps().length, 0);
      require('./lib/${moduleName}');
      assert.equal(admin.getApps().length, 1);
      require('firebase-admin/firestore').getFirestore();
    `], {
      cwd: path.resolve(__dirname, ".."),
      env: {...process.env, GCLOUD_PROJECT: "demo-bootstrap"},
      encoding: "utf8",
      timeout: 30000,
    });
    assert.equal(result.status, 0, result.stderr || String(result.error || ""));
  });
}
