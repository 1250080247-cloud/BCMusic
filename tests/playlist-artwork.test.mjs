import assert from 'node:assert/strict';
import test from 'node:test';
import { loadModule } from './helpers.mjs';
import { createHookHarness, findAll } from './ui-harness.mjs';

test('playlist artwork uses the latest four appended songs without changing playback order', async () => {
  const { default: Artwork } = await loadModule('src/components/PlaylistArtwork.js');
  const songs = Array.from({ length: 6 }, (_, index) => ({ id: `song-${index}`, thumbnail: `https://i.ytimg.com/vi/song-${index}/hqdefault.jpg` }));
  const original = JSON.stringify(songs);
  const tree = Artwork({ songs });
  const tiles = findAll(tree, node => node.props?.song);
  assert.deepEqual(tiles.map(node => node.props.song.id), ['song-5', 'song-4', 'song-3', 'song-2']);
  assert.equal(JSON.stringify(songs), original);
});

test('a playlist with fewer songs uses placeholders without borrowing or repeating other songs', async () => {
  const { default: Artwork } = await loadModule('src/components/PlaylistArtwork.js');
  for (const count of [0, 1, 2, 3]) {
    const songs = Array.from({ length: count }, (_, index) => ({ id: String(index), thumbnail: index ? null : 'https://i.ytimg.com/test.jpg' }));
    const tree = Artwork({ songs });
    const tiles = findAll(tree, node => typeof node.type === 'function');
    assert.equal(tiles.length, count > 1 ? 4 : 1);
    assert.equal(tiles.filter(node => node.props.song).length, count);
  }
});

test('a failed artwork image changes only that tile to the existing music placeholder', async () => {
  const harness = createHookHarness();
  const Image = () => null;
  const { default: Artwork } = await loadModule('src/components/PlaylistArtwork.js', { react: harness.react, 'next/image': { default: Image } });
  const tile = findAll(Artwork({ songs: [{ id: 'a', thumbnail: 'https://i.ytimg.com/test.jpg' }] }), node => node.props?.song)[0];
  let tree = harness.render(tile.type, tile.props);
  const image = findAll(tree, node => node.type === Image)[0];
  assert.ok(image);
  image.props.onError();
  tree = harness.render(tile.type, tile.props);
  assert.equal(findAll(tree, node => node.type === Image).length, 0);
  harness.unmount();
});
