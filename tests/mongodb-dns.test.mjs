import assert from 'node:assert/strict';
import test from 'node:test';
import { loadModule } from './helpers.mjs';

async function connectionFixture(uri, dnsServers) {
  const events = [];
  const connection = { connected: true };
  const { default: connect } = await loadModule('src/lib/mongodb.js', {
    'node:dns': {
      setServers: servers => events.push({ type: 'dns', servers: Array.from(servers) }),
      promises: { setServers: servers => events.push({ type: 'dns-promises', servers: Array.from(servers) }) },
    },
    mongoose: { default: { connect: async actualUri => {
      events.push({ type: 'connect', uri: actualUri });
      return connection;
    } } },
  }, {
    process: { env: { MONGODB_URI: uri, ...(dnsServers === undefined ? {} : { MONGODB_DNS_SERVERS: dnsServers }) } },
    global: {},
  });
  return { connect, events, connection };
}

test('MongoDB SRV uses explicitly configured DNS servers before connecting', async () => {
  const uri = 'mongodb+srv://cluster.example.invalid/music';
  const fixture = await connectionFixture(uri, ' 1.1.1.1, , 8.8.8.8 , ');
  assert.equal(await fixture.connect(), fixture.connection);
  assert.deepEqual(fixture.events, [
    { type: 'dns', servers: ['1.1.1.1', '8.8.8.8'] },
    { type: 'dns-promises', servers: ['1.1.1.1', '8.8.8.8'] },
    { type: 'connect', uri },
  ]);
});

test('cached MongoDB connections do not repeatedly reconfigure process DNS', async () => {
  const fixture = await connectionFixture('mongodb+srv://cluster.example.invalid/music', '1.1.1.1');
  await fixture.connect();
  await fixture.connect();
  assert.equal(fixture.events.filter(event => event.type === 'dns').length, 1);
  assert.equal(fixture.events.filter(event => event.type === 'dns-promises').length, 1);
  assert.equal(fixture.events.filter(event => event.type === 'connect').length, 1);
});

for (const empty of [undefined, '', '  ', ' , , ']) {
  test(`MongoDB SRV preserves system DNS when override is ${JSON.stringify(empty)}`, async () => {
    const uri = 'mongodb+srv://cluster.example.invalid/music';
    const fixture = await connectionFixture(uri, empty);
    await fixture.connect();
    assert.deepEqual(fixture.events, [{ type: 'connect', uri }]);
  });
}

test('standard MongoDB URIs preserve system DNS even when an SRV override is configured', async () => {
  const uri = 'mongodb://localhost:27017/music';
  const fixture = await connectionFixture(uri, '1.1.1.1,8.8.8.8');
  await fixture.connect();
  assert.deepEqual(fixture.events, [{ type: 'connect', uri }]);
});
