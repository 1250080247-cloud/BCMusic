import assert from 'node:assert/strict';
import test from 'node:test';
import { loadModule, jsonRequest } from './helpers.mjs';

const owner = '507f1f77bcf86cd799439011';
const scSong = {
  id: 'sc_12345', title: 'Track', source: 'soundcloud',
  embedUrl: 'https://w.soundcloud.com/player/?url=https%3A%2F%2Fapi.soundcloud.com%2Ftracks%2F12345',
  sourceUrl: 'https://soundcloud.com/artist/track',
};
const boundaries = {
  '@/lib/request-user': { getRequestUserId: async () => owner },
  '@/lib/mongodb': { default: async () => {} },
};

test('profile rejects its own avatar proxy URL without overwriting the original image', async () => {
  let image = 'data:image/png;base64,AA==';
  const route = await loadModule('src/app/api/user/update/route.js', {
    ...boundaries,
    '@/models/User': { default: { findByIdAndUpdate: async (id, update) => {
      image = update.$set.image ?? image;
      return { _id: owner, image };
    } } },
  });
  const response = await route.POST(jsonRequest('/api/user/update', {
    displayName: 'New name', image: `/api/user/avatar?userId=${owner}`,
  }));
  assert.equal(response.status, 400);
  assert.equal(image, 'data:image/png;base64,AA==');
});

test('renaming without an image field preserves the stored avatar', async () => {
  let update;
  const route = await loadModule('src/app/api/user/update/route.js', {
    ...boundaries,
    '@/models/User': { default: { findByIdAndUpdate: async (id, change) => {
      update = change.$set;
      return { _id: owner, displayName: update.displayName, image: 'https://example.com/avatar.png' };
    } } },
  });
  const response = await route.POST(jsonRequest('/api/user/update', { displayName: 'New name' }));
  assert.equal(response.status, 200);
  assert.equal(Object.hasOwn(update, 'image'), false);
});

test('legacy broken avatar URLs return the default image instead of a redirect error', async () => {
  const route = await loadModule('src/app/api/user/avatar/route.js', {
    ...boundaries,
    '@/models/User': { default: { findById: () => ({ lean: async () => ({ image: `/api/user/avatar?userId=${owner}` }) }) } },
  });
  const response = await route.GET(new Request(`http://localhost/api/user/avatar?userId=${owner}`));
  assert.equal(response.status, 200);
  assert.equal(response.headers.get('content-type'), 'image/svg+xml');
});

test('SoundCloud favorites retain playback metadata after saving and loading', async () => {
  let doc;
  const route = await loadModule('src/app/api/favorites/route.js', {
    ...boundaries,
    '@/models/Favorite': { default: {
      findOneAndUpdate: async (filter, update) => (doc = update),
      find: () => ({ sort: () => ({ lean: async () => [doc] }) }),
    } },
  });
  await route.POST(jsonRequest('/api/favorites', { song: scSong }));
  const response = await route.GET(new Request('http://localhost/api/favorites'));
  const { data } = await response.json();
  assert.equal(data[0].embedUrl, scSong.embedUrl);
  assert.equal(data[0].sourceUrl, scSong.sourceUrl);
});

test('SoundCloud history retains playback metadata in API and schema', async () => {
  let doc;
  const route = await loadModule('src/app/api/history/route.js', {
    ...boundaries,
    'next-auth': { getServerSession: async () => ({ user: { id: owner } }) },
    '@/lib/auth': { authOptions: {} },
    '@/models/History': { default: {
      findOneAndUpdate: async (filter, update) => (doc = { ...filter, ...update.$set }),
      find: () => ({ sort: () => ({ limit: () => ({ lean: async () => [doc] }) }) }),
    } },
  });
  await route.POST(jsonRequest('/api/history', scSong));
  const { data } = await (await route.GET(new Request('http://localhost/api/history'))).json();
  assert.equal(data[0].embedUrl, scSong.embedUrl);
  assert.equal(data[0].sourceUrl, scSong.sourceUrl);
  const { default: History } = await loadModule('src/models/History.js');
  const stored = new History({ ...scSong, songId: scSong.id }).toObject();
  assert.equal(stored.embedUrl, scSong.embedUrl);
  assert.equal(stored.sourceUrl, scSong.sourceUrl);
});

test('history never queries or writes a shared anonymous userId:null bucket', async () => {
  let savedOwner;
  const route = await loadModule('src/app/api/history/route.js', {
    ...boundaries,
    '@/lib/request-user': { getRequestUserId: async () => 'guest:first-visitor' },
    'next-auth': { getServerSession: async () => null },
    '@/lib/auth': { authOptions: {} },
    '@/models/History': { default: { findOneAndUpdate: async (filter) => {
      savedOwner = filter.userId;
      return filter;
    } } },
  });
  const response = await route.POST(jsonRequest('/api/history', { id: 'song', title: 'Song' }));
  assert.equal(response.status, 200);
  assert.equal(savedOwner, 'guest:first-visitor');
});

test('old SoundCloud entries recover metadata from the same owner library', async () => {
  const { restoreSoundCloudMetadata } = await loadModule('src/lib/song-metadata.js', {
    '@/models/SoundCloudTrack': { default: { find: (filter) => {
      assert.equal(filter.userId, owner);
      return { lean: async () => [{ scId: 'sc_12345', embedUrl: scSong.embedUrl, sourceUrl: scSong.sourceUrl }] };
    } } },
  });
  const [restored] = await restoreSoundCloudMetadata([{ id: 'sc_12345', source: 'soundcloud' }], owner);
  assert.equal(restored.embedUrl, scSong.embedUrl);
  assert.equal(restored.sourceUrl, scSong.sourceUrl);
});

test('old track entries can play by numeric ID when original metadata is unavailable', async () => {
  const { restoreSoundCloudMetadata } = await loadModule('src/lib/song-metadata.js', {
    '@/models/SoundCloudTrack': { default: { find: () => ({ lean: async () => [] }) } },
  });
  const [restored] = await restoreSoundCloudMetadata([{ id: 'sc_12345', source: 'soundcloud' }], owner);
  const resource = new URL(restored.embedUrl).searchParams.get('url');
  assert.equal(resource, 'https://api.soundcloud.com/tracks/12345');
});

test('a transient first MongoDB failure permits the next request to reconnect', async () => {
  let attempts = 0;
  const connection = { ready: true };
  const loadedModule = await loadModule('src/lib/mongodb.js', {
    mongoose: { default: { connect: async () => {
      attempts++;
      if (attempts === 1) throw new Error('Temporary outage');
      return connection;
    } } },
  }, { process: { env: { MONGODB_URI: 'mongodb://example.invalid/test' } }, global: {} });
  await assert.rejects(loadedModule.default(), /Temporary outage/);
  assert.equal(await loadedModule.default(), connection);
  assert.equal(attempts, 2);
});
