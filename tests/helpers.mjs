import { readFile } from 'node:fs/promises';
import path from 'node:path';
import { createRequire } from 'node:module';
import vm from 'node:vm';

const require = createRequire(import.meta.url);
const { transformSync } = require('next/dist/build/swc');
const root = path.resolve(import.meta.dirname, '..');

// Run real application modules while replacing only selected system boundaries.
// Each load gets its own module graph and global state.
export async function loadModule(file, options = {}, extraGlobals = {}) {
  const { stubs = options, globals = extraGlobals } = options;
  const context = vm.createContext({
    console: { log() {}, warn() {}, error() {} },
    process: { env: {} },
    Request, Response, Headers, URL, URLSearchParams, Buffer,
    AbortController, AbortSignal, TextEncoder, TextDecoder,
    setTimeout, clearTimeout, setInterval, clearInterval,
    ...globals,
  });
  const modules = new Map();

  function external(key, exports) {
    if (modules.has(key)) return modules.get(key);
    const values = { ...exports };
    if (!Object.hasOwn(values, 'default')) values.default = exports;
    const loadedModule = new vm.SyntheticModule(Object.keys(values), function () {
      for (const [name, value] of Object.entries(values)) this.setExport(name, value);
    }, { context, identifier: key });
    modules.set(key, loadedModule);
    return loadedModule;
  }

  async function source(filename) {
    if (modules.has(filename)) return modules.get(filename);
    const code = await readFile(filename, 'utf8');
    const transformed = transformSync(code, {
      filename,
      jsc: {
        target: 'es2022',
        parser: { syntax: 'ecmascript', jsx: true },
        transform: { react: { runtime: 'automatic' } },
      },
      module: { type: 'es6' },
    }).code;
    const loadedModule = new vm.SourceTextModule(transformed, { context, identifier: filename });
    modules.set(filename, loadedModule);
    return loadedModule;
  }

  async function resolve(specifier, referencingModule) {
    if (Object.hasOwn(stubs, specifier)) return external(`stub:${specifier}`, stubs[specifier]);
    if (specifier.startsWith('@/') || specifier.startsWith('.')) {
      let filename = specifier.startsWith('@/')
        ? path.resolve(root, 'src', specifier.slice(2))
        : path.resolve(path.dirname(referencingModule.identifier), specifier);
      if (!path.extname(filename)) filename += '.js';
      return source(filename);
    }
    return external(`package:${specifier}`, require(specifier));
  }

  const entry = await source(path.resolve(root, file));
  await entry.link(resolve);
  await entry.evaluate();
  return entry.namespace;
}

export function jsonRequest(url, body, method = 'POST') {
  return new Request(`http://localhost${url}`, {
    method,
    ...(body === undefined ? {} : {
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body),
    }),
  });
}
