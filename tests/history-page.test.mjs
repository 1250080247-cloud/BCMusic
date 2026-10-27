import assert from 'node:assert/strict';
import test from 'node:test';
import { loadModule } from './helpers.mjs';

test('HistoryPage with no verified identity never queries the shared anonymous history', async () => {
  let dbCalls = 0;
  const { default: HistoryPage } = await loadModule('src/app/history/page.js', {
    '@/lib/request-user': { getRequestUserId: async () => null },
    '@/lib/mongodb': { default: async () => { dbCalls++; throw new Error('Must not query DB'); } },
    '@/models/History': { default: {} },
    '@/lib/song-metadata': { restoreSoundCloudMetadata: async songs => songs },
    '@/components/HistoryView': { default: () => null },
    'next/server': { connection: async () => {} },
  });
  const tree = await HistoryPage();
  assert.equal(dbCalls, 0);
  assert.equal(tree.props.songs.length, 0);
});

test('HistoryPage reads only the verified guest owner instead of userId:null', async () => {
  const queries = [];
  const guestId = 'guest:verified-test-identity';
  const record = { songId: 'guest-song', title: 'My private guest song', listenedAt: new Date() };
  const { default: HistoryPage } = await loadModule('src/app/history/page.js', {
    '@/lib/request-user': { getRequestUserId: async options => options.allowGuest ? guestId : null },
    '@/lib/mongodb': { default: async () => {} },
    '@/models/History': {
      default: {
        find(query) {
          queries.push(query);
          return { sort() { return this; }, limit() { return this; }, lean: async () => [record] };
        },
      },
    },
    '@/lib/song-metadata': { restoreSoundCloudMetadata: async (songs, owner) => {
      assert.equal(owner, guestId);
      return songs;
    } },
    '@/components/HistoryView': { default: () => null },
    'next/server': { connection: async () => {} },
  });
  const tree = await HistoryPage();
  assert.equal(queries.length, 1);
  assert.equal(queries[0].userId, guestId);
  assert.equal(tree.props.songs[0].id, 'guest-song');
});
