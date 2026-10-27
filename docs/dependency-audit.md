# Dependency audit — 2026-10-28

`npm audit --json` now reports **0 vulnerabilities**, including development and optional dependencies. Before remediation, the full audit reported 13 affected packages (2 critical, 8 high, 3 moderate); the runtime-only audit reported 9 (2 critical, 4 high, 3 moderate).

## Remediation

| Package | Installed version |
| --- | --- |
| next, eslint-config-next | 16.4.3 |
| next-auth | 4.24.15 |
| mongoose | 9.7.2 |
| sharp | 0.35.5 |
| postcss | 8.5.23 |
| nanoid | 3.3.20 |
| source-map-js | 1.2.2 |
| baseline-browser-mapping | 2.11.33 |
| uuid | 11.1.1 |
| brace-expansion | 1.1.21 and 5.0.12 |
| browserslist | 4.29.4 |
| js-yaml | 4.3.2 |
| zod | 4.6.7 |

Next.js, NextAuth and Mongoose remain on their existing major versions. Runtime and lint Next.js packages are aligned. `uuid` is upgraded through NextAuth's own dependency range; no overrides or forced audit fixes are used. Direct security-sensitive versions are pinned in `package.json`; transitive versions are recorded in `package-lock.json`.

The changes also refresh the corresponding platform-specific Sharp/libvips and Next.js SWC packages. None of the upgraded packages adds an installation lifecycle script. `.npmrc` disables dependency lifecycle scripts, and `packageManager` records npm 11.19.0. Install with `npm ci`; do not bypass this policy with a blanket script approval.

GSAP 3.15.0, @gsap/react 2.1.2 and Framer Motion 12.40.0 are unchanged. MongoDB connection configuration, schemas and the connection URI are preserved. No database migration is part of the dependency upgrade. The subsequent player/lyrics redesign is documented separately in `docs/player-lyrics.md`.

`npm audit signatures`: 393 installed packages have verified registry signatures; 92 have verified attestations.

Final verification: a clean `npm ci --ignore-scripts --no-audit --no-fund --prefer-offline` completed successfully (393 packages); Sharp produced an in-memory WebP after that installation. `npm test` passed all 129 tests after the lyrics follow-up, `npm run lint` passed, and `npm run build` completed successfully with Next.js 16.4.3. The full dependency audit still reports zero vulnerabilities. Authentication regression tests cover malformed Bearer values, synthetic legacy encrypted sessions, valid credentials and rejected credentials.

Read-only MongoDB ping and production API checks succeeded. Existing business records and indexes were compared before and after verification; the details and browser verification limits are recorded in [verification-2026-10-28.md](verification-2026-10-28.md).

Primary sources: [Next.js 16.4.3 release](https://github.com/vercel/next.js/releases/tag/v16.4.3), [NextAuth 4.24.15 release](https://github.com/nextauthjs/next-auth/releases/tag/next-auth@4.24.15), [NextAuth malformed Bearer advisory](https://github.com/advisories/GHSA-xmf8-cvqr-rfgj), [Mongoose advisory](https://github.com/advisories/GHSA-664h-wqgq-64gw). The complete affected graph and final versions were checked with npm's audit and dependency-tree commands.
