import assert from 'node:assert/strict';
import test from 'node:test';
import { loadModule, jsonRequest } from './helpers.mjs';

const invalidRequests = [
  ['src/app/api/playlist/song/route.js', 'POST', '/api/playlist/song', { playlistId: { $ne: null }, song: { id: 'song', title: 'Song' } }],
  ['src/app/api/playlist/song/route.js', 'DELETE', '/api/playlist/song', { playlistId: { $ne: null }, songId: 'song' }],
  ['src/app/api/playlist/route.js', 'POST', '/api/playlist', { name: '' }],
  ['src/app/api/playlist/route.js', 'DELETE', '/api/playlist', { playlistId: { $ne: null } }],
  ['src/app/api/favorites/route.js', 'POST', '/api/favorites', { song: { id: { $ne: null }, title: 'Song' } }],
  ['src/app/api/favorites/route.js', 'DELETE', '/api/favorites', undefined],
  ['src/app/api/user/avatar/route.js', 'GET', '/api/user/avatar?userId=invalid', undefined],
];

for (const [file, method, url, body] of invalidRequests) {
  test(`${method} ${url} validates input even when MongoDB is unavailable`, async () => {
    let dbCalls = 0;
    const route = await loadModule(file, {
      '@/lib/request-user': { getRequestUserId: async () => '507f1f77bcf86cd799439011' },
      '@/lib/mongodb': { default: async () => { dbCalls++; throw new Error('DB unavailable'); } },
      '@/models/User': { default: {} },
      '@/models/Playlist': { default: {} },
      '@/models/Favorite': { default: {} },
      '@/models/SoundCloudTrack': { default: {} },
    });
    const response = await route[method](jsonRequest(url, body, method));
    assert.equal(response.status, 400);
    assert.equal(dbCalls, 0);
  });
}
