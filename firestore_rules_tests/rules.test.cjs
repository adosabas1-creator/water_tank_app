const fs = require('node:fs');
const path = require('node:path');
const { after, before, beforeEach, test } = require('node:test');
const {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} = require('@firebase/rules-unit-testing');
const { doc, setDoc } = require('firebase/firestore');

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
