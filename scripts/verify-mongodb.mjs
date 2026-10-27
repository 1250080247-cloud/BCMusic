import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { fileURLToPath } from 'node:url';
import nextEnv from '@next/env';
import mongoose from 'mongoose';

nextEnv.loadEnvConfig(fileURLToPath(new URL('..', import.meta.url)));

// Verification must never build indexes, migrate collections, or change old records.
mongoose.set('autoIndex', false);
mongoose.set('autoCreate', false);
const pendingCleanup = [];

async function cleanup() {
  for (const entry of [...pendingCleanup].reverse()) {
    // Read ownership evidence before deleting only this run's exact document.
    if (await entry.model.exists(entry.filter)) {
      await entry.model.deleteOne(entry.filter);
    }
    assert.equal(await entry.model.exists(entry.filter), null, 'Temporary record cleanup failed');
    pendingCleanup.splice(pendingCleanup.indexOf(entry), 1);
  }
}

async function main() {
  const { default: dbConnect } = await import('../src/lib/mongodb.js');
  await dbConnect();
  await mongoose.connection.db.admin().ping();
  console.log('MongoDB connection and ping: PASS');
  if (!process.argv.includes('--crud')) return;

  const runId = randomUUID().replaceAll('-', '');
  const ownerId = new mongoose.Types.ObjectId();
  const userId = ownerId.toString();
  const songId = `codex-verify-${runId}`;
  const scId = `sc_verify_${runId}`;
  const cacheKey = `codex-verify:${runId}`;
  const username = `verify_${runId.slice(0, 20)}`;
  const song = { id: songId, title: 'Temporary CRUD verification', source: 'youtube' };
  const scMetadata = {
    source: 'soundcloud',
    embedUrl: 'https://w.soundcloud.com/player/?url=https%3A%2F%2Fapi.soundcloud.com%2Ftracks%2F12345',
    sourceUrl: 'https://soundcloud.com/verification/temporary-track',
  };
  const cases = [
    { name: 'User', id: ownerId, identity: { username }, data: { username, displayName: 'Temporary CRUD verification', password: null }, patch: { displayName: 'Verified temporary profile' } },
    { name: 'Playlist', identity: { userId }, data: { userId, name: 'Temporary CRUD verification', songs: [song] }, patch: { name: 'Verified temporary playlist' } },
    { name: 'Favorite', identity: { userId, songId }, data: { userId, songId, title: song.title, ...scMetadata }, patch: { title: 'Verified temporary favorite' } },
    { name: 'History', identity: { userId, songId }, data: { userId, songId, title: song.title, ...scMetadata }, patch: { title: 'Verified temporary history' } },
    { name: 'SoundCloudTrack', identity: { userId, scId }, data: { userId, scId, title: song.title, embedUrl: scMetadata.embedUrl, sourceUrl: scMetadata.sourceUrl }, patch: { title: 'Verified temporary SoundCloud track' } },
    { name: 'SongCache', identity: { cacheKey }, data: { cacheKey, query: 'temporary verification', order: 'relevance', songs: [song] }, patch: { query: 'verified temporary cache' } },
  ];
  const existingCollections = new Set((await mongoose.connection.db.listCollections({}, { nameOnly: true }).toArray()).map((entry) => entry.name));
  const checked = [];

  for (const scenario of cases) {
    const { default: model } = await import(`../src/models/${scenario.name}.js`);
    if (!existingCollections.has(model.collection.name)) {
      console.log(`CRUD ${scenario.name}: SKIPPED (collection does not exist; no collection created)`);
      continue;
    }
    checked.push({
      ...scenario, model,
      beforeCount: await model.countDocuments({}),
      beforeIndexes: JSON.stringify(await model.collection.indexes()),
    });
  }
  assert.ok(checked.length, 'No existing application collections available for CRUD verification');

  for (const scenario of checked) {
    const { model, identity, data, patch } = scenario;
    const _id = scenario.id || new mongoose.Types.ObjectId();
    assert.equal(await model.exists({ _id }), null, 'Refusing to overwrite an existing document');
    const filter = { _id, ...identity };
    // Register before insert so an ambiguous network failure still gets exact cleanup.
    pendingCleanup.push({ model, filter });
    await model.create({ _id, ...data });
    const created = await model.findOne(filter).lean();
    assert.ok(created, 'Created document was not readable');
    for (const [key, value] of Object.entries(data)) {
      if (typeof value === 'string') assert.equal(created[key], value);
    }
    const updated = await model.updateOne(filter, { $set: patch }, { runValidators: true });
    assert.equal(updated.matchedCount, 1);
    assert.equal(updated.modifiedCount, 1);
    const reread = await model.findOne(filter).lean();
    for (const [key, value] of Object.entries(patch)) assert.equal(reread[key], value);
    const deleted = await model.deleteOne(filter);
    assert.equal(deleted.deletedCount, 1);
    assert.equal(await model.exists(filter), null);
    pendingCleanup.splice(pendingCleanup.findIndex((entry) => entry.filter === filter), 1);
    console.log(`CRUD ${scenario.name}: PASS (create/read/update/delete)`);
  }

  for (const { model, beforeCount, beforeIndexes } of checked) {
    assert.equal(await model.countDocuments({}), beforeCount, `${model.modelName} count changed during verification`);
    assert.equal(JSON.stringify(await model.collection.indexes()), beforeIndexes, `${model.modelName} indexes changed during verification`);
  }
  console.log('Cleanup: PASS; original document counts and indexes unchanged.');
}

try {
  await main();
} catch (error) {
  console.error('MongoDB verification failed:', error.message.replace(/mongodb(?:\+srv)?:\/\/[^\s]+/g, '[REDACTED_URI]'));
  process.exitCode = 1;
} finally {
  try {
    await cleanup();
  } catch {
    console.error('Temporary test cleanup failed. Unremoved test IDs:', pendingCleanup.map(({ model, filter }) => `${model.modelName}:${filter._id}`));
    process.exitCode = 1;
  }
  await mongoose.disconnect();
}
