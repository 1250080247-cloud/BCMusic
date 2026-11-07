import assert from 'node:assert/strict';
import test from 'node:test';
import { loadModule, jsonRequest } from './helpers.mjs';

// The Android app (mobile/android/.../AccountClient.kt) validates song titles up to 500
// characters before it calls these routes. The web API must accept every value the app
// considers valid, otherwise the save fails with a generic error.
const owner = '507f1f77bcf86cd799439011';
const playlistId = '65a1b2c3d4e5f60718293a4b';
const boundaries = {
  '@/lib/request-user': { getRequestUserId: async () => owner },
  '@/lib/mongodb': { default: async () => {} },
};
const song = (title, extra = {}) => ({
  id: 'dQw4w9WgXcQ', title, artist: 'Artist', source: 'youtube',
  sourceUrl: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ', ...extra,
});

async function favoritesRoute(saved = []) {
  return loadModule('src/app/api/favorites/route.js', {
    ...boundaries,
    '@/models/Favorite': { default: {
      findOneAndUpdate: async (filter, update) => { saved.push(update); return update; },
    } },
  });
}

async function playlistSongRoute(saved = []) {
  return loadModule('src/app/api/playlist/song/route.js', {
    ...boundaries,
    '@/models/Playlist': { default: {
      findOne: async () => ({ songs: [] }),
      updateOne: async (filter, update) => { saved.push(update); return { matchedCount: 1 }; },
    } },
  });
}

test('favorites accept a 500-character title, the same limit the Android app validates', async () => {
  const saved = [];
  const route = await favoritesRoute(saved);
  const response = await route.POST(jsonRequest('/api/favorites', { song: song('a'.repeat(500)) }));
  assert.equal(response.status, 200);
  assert.equal(saved[0].title.length, 500);
});

test('favorites reject titles longer than 500 characters', async () => {
  const route = await favoritesRoute();
  const response = await route.POST(jsonRequest('/api/favorites', { song: song('a'.repeat(501)) }));
  assert.equal(response.status, 400);
});

test('playlist songs accept a 500-character title, the same limit the Android app validates', async () => {
  const saved = [];
  const route = await playlistSongRoute(saved);
  const response = await route.POST(jsonRequest('/api/playlist/song', {
    playlistId, song: song('b'.repeat(500)),
  }));
  assert.equal(response.status, 200);
  assert.equal(saved[0].$push.songs.title.length, 500);
});

test('playlist songs reject titles longer than 500 characters', async () => {
  const route = await playlistSongRoute();
  const response = await route.POST(jsonRequest('/api/playlist/song', {
    playlistId, song: song('b'.repeat(501)),
  }));
  assert.equal(response.status, 400);
});
