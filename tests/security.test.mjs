import assert from 'node:assert/strict';
import test from 'node:test';
import { createElement } from 'react';
import { renderToStaticMarkup } from 'react-dom/server';
import { jsonRequest, loadModule } from './helpers.mjs';

const ownerId = '507f1f77bcf86cd799439011';
const victimId = '507f191e810c19729de860ea';
const playlistId = '507f1f77bcf86cd799439012';
const song = { id: 'test-song', title: 'A song' };
const scSong = {
  id: 'sc_12345', scTrackId: '12345', title: 'SoundCloud song',
  embedUrl: 'https://w.soundcloud.com/player/?url=https%3A%2F%2Fapi.soundcloud.com%2Ftracks%2F12345',
};

const endpoints = [
  ['src/app/api/user/update/route.js', 'POST', '/api/user/update', { userId: victimId, displayName: 'Renamed' }],
  ['src/app/api/favorites/route.js', 'GET', `/api/favorites?userId=${victimId}`, undefined],
  ['src/app/api/favorites/route.js', 'POST', '/api/favorites', { userId: victimId, song }],
  ['src/app/api/favorites/route.js', 'DELETE', `/api/favorites?userId=${victimId}&songId=test-song`, undefined],
  ['src/app/api/playlist/route.js', 'GET', `/api/playlist?userId=${victimId}`, undefined],
  ['src/app/api/playlist/route.js', 'POST', '/api/playlist', { userId: victimId, name: 'Private' }],
  ['src/app/api/playlist/route.js', 'DELETE', '/api/playlist', { userId: victimId, playlistId }],
  ['src/app/api/playlist/song/route.js', 'POST', '/api/playlist/song', { userId: victimId, playlistId, song }],
  ['src/app/api/playlist/song/route.js', 'DELETE', '/api/playlist/song', { userId: victimId, playlistId, songId: song.id }],
  ['src/app/api/soundcloud/import/route.js', 'GET', `/api/soundcloud/import?userId=${victimId}`, undefined],
  ['src/app/api/soundcloud/import/route.js', 'POST', '/api/soundcloud/import', { userId: victimId, url: 'https://soundcloud.com/example/track' }],
  ['src/app/api/soundcloud/import/route.js', 'DELETE', '/api/soundcloud/import', { userId: victimId, scId: scSong.id }],
];

function boundaryStubs(userId, model) {
  return {
    '@/lib/request-user': { getRequestUserId: async () => userId },
    '@/lib/mongodb': { default: async () => {} },
    '@/lib/soundcloud': { resolveSoundCloudUrl: async () => scSong },
    '@/models/User': { default: model },
    '@/models/Favorite': { default: model },
    '@/models/Playlist': { default: model },
    '@/models/SoundCloudTrack': { default: model },
  };
}

for (const [file, method, url, body] of endpoints) {
  test(`${method} ${url.split('?')[0]} rejects missing server identity before accessing DB`, async () => {
    let dbCalls = 0;
    let remoteCalls = 0;
    const stubs = boundaryStubs(null, {});
    stubs['@/lib/mongodb'].default = async () => { dbCalls++; throw new Error('DB must not be accessed'); };
    stubs['@/lib/soundcloud'].resolveSoundCloudUrl = async () => { remoteCalls++; return scSong; };
    const route = await loadModule(file, { stubs });
    const response = await route[method](jsonRequest(url, body, method));
    assert.equal(response.status, 401);
    assert.equal(dbCalls, 0);
    assert.equal(remoteCalls, 0);
  });

  test(`${method} ${url.split('?')[0]} uses server owner instead of client userId`, async () => {
    const owners = [];
    const record = { _id: ownerId, displayName: 'Owner', image: null, name: 'Private', songs: [], importedAt: new Date(), createdAt: new Date() };
    const noteOwner = input => {
      owners.push(input.userId ?? input);
    };
    const query = value => ({ sort() { return this; }, lean: async () => value });
    const model = {
      find(input) { noteOwner(input); return query([]); },
      findOne(input) {
        noteOwner(input);
        return Object.assign(Promise.resolve({ ...record, songs: [], save: async () => {} }), {
          lean: async () => null,
        });
      },
      async findByIdAndUpdate(id) { noteOwner(id); return record; },
      async findOneAndUpdate(input) { noteOwner(input); return record; },
      async create(input) { noteOwner(input); return { ...record, ...input }; },
      async deleteOne(input) { noteOwner(input); return { deletedCount: 1 }; },
      async updateOne(input) { noteOwner(input); return { matchedCount: 1, modifiedCount: 1 }; },
    };
    const route = await loadModule(file, { stubs: boundaryStubs(ownerId, model) });
    const response = await route[method](jsonRequest(url, body, method));
    assert.ok(response.ok, `expected success, got ${response.status}: ${await response.text()}`);
    assert.ok(owners.length > 0, 'the request should access data for the authenticated owner');
    assert.ok(owners.every(id => id === ownerId), `owners accessed: ${JSON.stringify(owners)}`);
  });
}

test('song title HTML is rendered as text instead of executable markup', async () => {
  const state = {
    setCurrentSong() {}, setViewingSong() {}, setPlaylist() {}, startPlayback() {},
    language: 'en',
  };
  const store = selector => selector ? selector(state) : state;
  const { default: SongCard } = await loadModule('src/components/SongCard.js', {
    stubs: {
      '@/lib/store': { useMusicStore: store, useSettingsStore: store },
      'next/image': { default: () => null },
    },
  });
  const payload = '<img src=x onerror="document.body.dataset.injected=1">';
  const markup = renderToStaticMarkup(createElement(SongCard, {
    song: { ...song, title: payload }, playlist: [song],
  }));
  assert.equal(markup.includes('<img'), false);
  assert.ok(markup.includes('&lt;img'), 'the literal title must remain visible as escaped text');
});

test('encoded title entities remain readable without becoming HTML', async () => {
  const state = { setCurrentSong() {}, setViewingSong() {}, setPlaylist() {}, startPlayback() {}, language: 'en' };
  const store = selector => selector ? selector(state) : state;
  const { default: SongCard } = await loadModule('src/components/SongCard.js', {
    stubs: {
      '@/lib/store': { useMusicStore: store, useSettingsStore: store },
      'next/image': { default: () => null },
    },
  });
  const markup = renderToStaticMarkup(createElement(SongCard, {
    song: { ...song, title: 'Rock &amp; Roll &#39;Live&#39; &lt;b&gt;' }, playlist: [song],
  }));
  assert.ok(markup.includes('Rock &amp; Roll &#x27;Live&#x27; &lt;b&gt;'));
  assert.equal(markup.includes('<b>'), false);
});
