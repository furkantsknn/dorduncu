import fs from 'node:fs';
import {after, before, test} from 'node:test';
import {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} from '@firebase/rules-unit-testing';
import {doc, getDoc, setDoc} from 'firebase/firestore';

let env;
before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-admin-management-numbers',
    firestore: {rules: fs.readFileSync('../../firestore.rules', 'utf8')},
  });
  await env.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), 'admin_user_metadata/user-1'), {
      uid: 'user-1', managementNumber: 'U-000001',
    });
    await setDoc(doc(context.firestore(), 'admin_counters/users'), {
      lastSequence: 1,
    });
    await setDoc(doc(context.firestore(), 'support_requests/request-secret'), {
      userId: 'owner-1', ticketId: 'DST-2026-000001', status: 'new',
    });
  });
});

test('guessing a support number or document id grants no access', async () => {
  const stranger = env.authenticatedContext('stranger').firestore();
  const owner = env.authenticatedContext('owner-1').firestore();
  await assertFails(getDoc(doc(stranger, 'support_requests/request-secret')));
  await assertSucceeds(getDoc(doc(owner, 'support_requests/request-secret')));
});
after(async () => env?.cleanup());

test('ordinary users cannot read management numbers or counters', async () => {
  const db = env.authenticatedContext('user-1').firestore();
  await assertFails(getDoc(doc(db, 'admin_user_metadata/user-1')));
  await assertFails(getDoc(doc(db, 'admin_counters/users')));
});

test('authorized admins can read metadata but no client can write it', async () => {
  const db = env.authenticatedContext('admin-1', {admin: true}).firestore();
  const metadata = doc(db, 'admin_user_metadata/user-1');
  await assertSucceeds(getDoc(metadata));
  await assertFails(setDoc(metadata, {managementNumber: 'U-999999'}));
  await assertFails(setDoc(doc(db, 'admin_counters/users'), {lastSequence: 2}));
});
