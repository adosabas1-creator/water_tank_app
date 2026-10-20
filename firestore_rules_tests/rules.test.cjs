const fs = require('node:fs');
const path = require('node:path');
const { after, before, beforeEach, test } = require('node:test');
const {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} = require('@firebase/rules-unit-testing');
const { collection, deleteDoc, doc, getDoc, getDocs, setDoc, updateDoc } = require('firebase/firestore');

const projectId = 'demo-alborai-water-tank';
const rules = fs.readFileSync(path.join(__dirname, '..', 'firestore.rules'), 'utf8');
let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId,
    firestore: { rules },
  });
});

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (context) => {
    await setDoc(
      doc(context.firestore(), 'businesses/alborai_water_tank/user_directory/allowed-uid'),
      {
        role: 'member',
        sync_id: 'sync-allowed',
        permissions: { logs_view: true },
      },
    );
    await setDoc(
      doc(context.firestore(), 'businesses/alborai_water_tank/user_directory/denied-uid'),
      {
        role: 'member',
        sync_id: 'sync-denied',
        permissions: { logs_view: false },
      },
    );
    await setDoc(
      doc(context.firestore(), 'businesses/alborai_water_tank/user_directory/admin-uid'),
      {
        role: 'admin',
        sync_id: 'sync-admin',
        permissions: {},
      },
    );
    await setDoc(
      doc(context.firestore(), 'businesses/alborai_water_tank/user_directory/deputy-uid'),
      {
        role: 'deputy_manager',
        sync_id: 'sync-deputy',
        permissions: {},
      },
    );
    await setDoc(
      doc(context.firestore(), 'businesses/alborai_water_tank/login_directory/sample-user'),
      { username: 'sample-user', firebase_uid: 'allowed-uid' },
    );
  });
});

after(async () => {
  await env?.cleanup();
});

function logData(userSyncId) {
  return {
    user_sync_id: userSyncId,
    action: 'test',
    created_at: '2026-10-20T00:00:00.000Z',
  };
}

test('permits operation log creation with logs_view and matching sync identity', async () => {
  const db = env.authenticatedContext('allowed-uid').firestore();
  await assertSucceeds(setDoc(
    doc(db, 'businesses/alborai_water_tank/operation_logs/log-allowed'),
    logData('sync-allowed'),
  ));
});

test('denies operation log creation without logs_view permission', async () => {
  const db = env.authenticatedContext('denied-uid').firestore();
  await assertFails(setDoc(
    doc(db, 'businesses/alborai_water_tank/operation_logs/log-denied'),
    logData('sync-denied'),
  ));
});

test('denies operation log creation when sync identity does not match', async () => {
  const db = env.authenticatedContext('allowed-uid').firestore();
  await assertFails(setDoc(
    doc(db, 'businesses/alborai_water_tank/operation_logs/log-mismatch'),
    logData('sync-other-user'),
  ));
});

test('denies unauthenticated operation log creation', async () => {
  const db = env.unauthenticatedContext().firestore();
  await assertFails(setDoc(
    doc(db, 'businesses/alborai_water_tank/operation_logs/log-unauthenticated'),
    logData('sync-allowed'),
  ));
});

test('permits admins to create logs with their own sync identity', async () => {
  const db = env.authenticatedContext('admin-uid').firestore();
  await assertSucceeds(setDoc(
    doc(db, 'businesses/alborai_water_tank/operation_logs/log-admin'),
    logData('sync-admin'),
  ));
});

test('permits deputy managers to create logs with their own sync identity', async () => {
  const db = env.authenticatedContext('deputy-uid').firestore();
  await assertSucceeds(setDoc(
    doc(db, 'businesses/alborai_water_tank/operation_logs/log-deputy'),
    logData('sync-deputy'),
  ));
});


test('denies direct get access to login_directory documents', async () => {
  const db = env.authenticatedContext('allowed-uid').firestore();
  await assertFails(getDoc(
    doc(db, 'businesses/alborai_water_tank/login_directory/sample-user'),
  ));
});

test('denies list access to login_directory documents', async () => {
  const db = env.authenticatedContext('admin-uid').firestore();
  await assertFails(getDocs(
    collection(db, 'businesses/alborai_water_tank/login_directory'),
  ));
});

test('denies members from creating arbitrary login directory entries', async () => {
  const db = env.authenticatedContext('allowed-uid', {
    email: 'member@example.com',
  }).firestore();
  await assertFails(setDoc(
    doc(db, 'businesses/alborai_water_tank/login_directory/arbitrary-name'),
    {
      username: 'arbitrary-name',
      firebase_uid: 'allowed-uid',
      firebase_email: 'member@example.com',
    },
  ));
});

test('permits admins to create login directory entries', async () => {
  const db = env.authenticatedContext('admin-uid', {
    email: 'admin@example.com',
  }).firestore();
  await assertSucceeds(setDoc(
    doc(db, 'businesses/alborai_water_tank/login_directory/new-user'),
    {
      username: 'new-user',
      firebase_uid: 'new-user-uid',
      firebase_email: 'new-user@example.com',
    },
  ));
});

test('denies members from deleting login directory entries', async () => {
  const db = env.authenticatedContext('allowed-uid').firestore();
  await assertFails(deleteDoc(
    doc(db, 'businesses/alborai_water_tank/login_directory/sample-user'),
  ));
});

test('denies members from updating login directory entries', async () => {
  const db = env.authenticatedContext('allowed-uid').firestore();
  await assertFails(updateDoc(
    doc(db, 'businesses/alborai_water_tank/login_directory/sample-user'),
    { firebase_uid: 'attacker-uid' },
  ));
});

test('permits admins to update login directory entries', async () => {
  const db = env.authenticatedContext('admin-uid').firestore();
  await assertSucceeds(updateDoc(
    doc(db, 'businesses/alborai_water_tank/login_directory/sample-user'),
    { firebase_uid: 'updated-uid' },
  ));
});

test('permits admins to delete login directory entries', async () => {
  const db = env.authenticatedContext('admin-uid').firestore();
  await assertSucceeds(deleteDoc(
    doc(db, 'businesses/alborai_water_tank/login_directory/sample-user'),
  ));
});
