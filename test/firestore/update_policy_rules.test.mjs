import fs from 'node:fs';
import {after, before, test} from 'node:test';
import assert from 'node:assert/strict';
import {initializeTestEnvironment, assertFails, assertSucceeds} from '@firebase/rules-unit-testing';
import {doc, getDoc, setDoc} from 'firebase/firestore';

let env;
before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-update-policy',
    firestore: {rules: fs.readFileSync('../../firestore.rules', 'utf8')},
  });
  await env.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), 'public_app_versions/android_production'), {active: false, latestBuild: 31, minimumBuild: 0});
  });
});
after(async () => env?.cleanup());

test('signed-out clients can read only public version policy', async () => {
  const db = env.unauthenticatedContext().firestore();
  await assertSucceeds(getDoc(doc(db, 'public_app_versions/android_production')));
  await assertFails(getDoc(doc(db, 'app_version_policies/android_production')));
  await assertFails(setDoc(doc(db, 'public_app_versions/android_production'), {active: true}));
  assert.ok(true);
});

test('only admins can inspect private policy and no client can write it', async () => {
  const userDb = env.authenticatedContext('user-1').firestore();
  const adminDb = env.authenticatedContext('admin-1', {admin: true}).firestore();
  const privateRef = doc(adminDb, 'app_version_policies/android_production');
  await assertFails(getDoc(doc(userDb, 'app_version_policies/android_production')));
  await assertSucceeds(getDoc(privateRef));
  await assertFails(setDoc(privateRef, {active: true}));
});
