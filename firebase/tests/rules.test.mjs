import { after, before, beforeEach, test } from 'node:test';
import { readFileSync } from 'node:fs';
import { initializeTestEnvironment, assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import { ref, get, set, remove, update } from 'firebase/database';

let environment;
const cameraURL = 'https://front.example.com/video_feed';
const ownLog = 'cameraLogs/front/Knife/event';
const database = (uid) => uid ? environment.authenticatedContext(uid).database() : environment.unauthenticatedContext().database();

before(async () => {
  environment = await initializeTestEnvironment({
    projectId: 'demo-sam-security',
    database: { rules: readFileSync(new URL('../database.rules.json', import.meta.url), 'utf8') },
  });
});
after(async () => { await environment?.cleanup(); });
beforeEach(async () => {
  await environment.clearDatabase();
  await environment.withSecurityRulesDisabled(async context => {
    await set(ref(context.database()), {
      cameras: { front: { url: cameraURL }, back: { url: 'https://back.example.com/video_feed' } },
      cameraMembers: { front: { alice: true }, back: { bob: true } },
      users: { alice: { linked_cameras: { front: cameraURL } }, bob: { linked_cameras: { back: 'https://back.example.com/video_feed' } } },
      cameraLogs: { front: { Knife: { event: { date: '2026-01-01', timestamp: 1, confidence: 0.9, photoBase64: 'jpeg', cameraID: 'front' } } } },
      logs: { legacy: 'private archive' },
    });
  });
});

test('anonymous users cannot read metadata, logs or links', async () => {
  for (const path of ['cameras/front', ownLog, 'users/alice/linked_cameras']) {
    await assertFails(get(ref(database(), path)));
  }
});
test('member reads own camera and logs, not another camera or the root', async () => {
  await assertSucceeds(get(ref(database('alice'), ownLog)));
  await assertSucceeds(get(ref(database('alice'), 'cameras/front')));
  for (const path of ['cameras/back', 'cameraLogs/back', 'cameraLogs', 'users/bob/linked_cameras', 'logs']) {
    await assertFails(get(ref(database('alice'), path)));
  }
});
test('clients cannot grant themselves membership or change camera metadata', async () => {
  await assertFails(set(ref(database('bob'), 'cameraMembers/front/bob'), true));
  await assertFails(set(ref(database('alice'), 'cameras/front/url'), 'https://attacker.test/video_feed'));
  await assertFails(update(ref(database('bob')), {
    'cameraMembers/front/bob': true, 'users/bob/linked_cameras/front': cameraURL,
  }));
});
test('linking requires a grant and the exact registered URL', async () => {
  await assertSucceeds(set(ref(database('alice'), 'users/alice/linked_cameras/front'), cameraURL));
  await assertFails(set(ref(database('bob'), 'users/bob/linked_cameras/front'), cameraURL));
  await assertFails(set(ref(database('alice'), 'users/alice/linked_cameras/front'), 'https://attacker.test'));
  await assertFails(set(ref(database('bob'), 'users/alice/linked_cameras/front'), cameraURL));
});
test('members may delete an event but cannot forge or edit evidence', async () => {
  await assertFails(set(ref(database('alice'), ownLog + '/confidence'), 1));
  await assertFails(set(ref(database('alice'), 'cameraLogs/front/Knife/fake'), { confidence: 1 }));
  await assertFails(remove(ref(database('bob'), ownLog)));
  await assertFails(remove(ref(database('alice'), 'cameraLogs/front')));
  await assertSucceeds(remove(ref(database('alice'), ownLog)));
});
test('unlink removes log access and cannot remove another users links', async () => {
  await assertFails(remove(ref(database('bob'), 'users/alice/linked_cameras/front')));
  await assertSucceeds(remove(ref(database('alice'), 'users/alice/linked_cameras/front')));
  await assertFails(get(ref(database('alice'), ownLog)));
});
test('revoking membership blocks existing links and evidence access', async () => {
  await environment.withSecurityRulesDisabled(async context => {
    await remove(ref(context.database(), 'cameraMembers/front/alice'));
  });
  await assertFails(get(ref(database('alice'), ownLog)));
  await assertFails(remove(ref(database('alice'), ownLog)));
  await assertFails(set(ref(database('alice'), 'users/alice/linked_cameras/front'), cameraURL));
  await assertSucceeds(remove(ref(database('alice'), 'users/alice/linked_cameras/front')));
});
test('feedback is create-only, bounded, private and UID-scoped', async () => {
  const entry = { feedback: 'Camera works.', timestamp: Date.now() };
  await assertSucceeds(set(ref(database('alice'), 'feedback/alice/message'), entry));
  await assertFails(get(ref(database('bob'), 'feedback/alice/message')));
  await assertFails(set(ref(database('bob'), 'feedback/alice/forged'), entry));
  await assertFails(set(ref(database('alice'), 'feedback/alice/message'), entry));
  await assertFails(set(ref(database('alice'), 'feedback/alice/oversized'), { ...entry, feedback: 'x'.repeat(5001) }));
  await assertFails(set(ref(database('alice'), 'feedback/alice/extra'), { ...entry, admin: true }));
});
