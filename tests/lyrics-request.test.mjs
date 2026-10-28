import assert from 'node:assert/strict';
import test from 'node:test';
import { loadModule } from './helpers.mjs';

test('lyrics transport decodes UTF-8 split across response chunks', async () => {
  const text = JSON.stringify({ lyrics: 'Lời kiểm thử được viết riêng.' });
  const bytes = new TextEncoder().encode(text);
  const stream = new ReadableStream({ start(controller) {
    for (const byte of bytes) controller.enqueue(new Uint8Array([byte]));
    controller.close();
  } });
  const { requestLyricsJson } = await loadModule('src/lib/lyrics-request.js', {}, { fetch: async () => new Response(stream) });
  const data = await requestLyricsJson(new URL('https://api.lyrics.ovh/v1/Artist/Song'));
  assert.equal(data.lyrics, 'Lời kiểm thử được viết riêng.');
});

test('oversized unannounced responses are canceled while streaming', async () => {
  let canceled = false;
  const stream = new ReadableStream({ pull(controller) { controller.enqueue(new Uint8Array(256001)); }, cancel() { canceled = true; } });
  const { requestLyricsJson } = await loadModule('src/lib/lyrics-request.js', {}, { fetch: async () => new Response(stream) });
  await assert.rejects(requestLyricsJson(new URL('https://api.lyrics.ovh/v1/Artist/Song')), /too_large/);
  assert.equal(canceled, true);
});

test('lyrics transport rejects any origin outside the two fixed providers', async () => {
  let calls = 0;
  const { requestLyricsJson } = await loadModule('src/lib/lyrics-request.js', {}, { fetch: async () => { calls++; return Response.json({}); } });
  for (const address of ['http://lrclib.net/api/get', 'https://example.com/', 'http://127.0.0.1/']) await assert.rejects(requestLyricsJson(new URL(address)), /invalid_lyrics_provider/);
  assert.equal(calls, 0);
});

test('a standalone dot segment cannot change the backup route', async () => {
  let calls = 0;
  const { lookupOvhLyrics } = await loadModule('src/lib/lyrics-ovh.js', {}, { fetch: async () => { calls++; return Response.json({ lyrics: 'Original test text' }); } });
  for (const artist of ['.', '..']) assert.equal(await lookupOvhLyrics({ artist, title: 'Song' }), null);
  assert.equal(calls, 0);
});
