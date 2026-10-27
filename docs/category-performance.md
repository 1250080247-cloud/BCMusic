# Category navigation performance — 2026-10-28

## Root causes and changes

The category page awaited all three feeds before rendering its header and music sections. A slow newest/ranking request therefore delayed every section. The page now starts those requests together and streams ranking, each horizontal row and pagination through separate keyed Suspense boundaries. Loading rows retain the selected category's heading and expose `aria-busy`; changing category resets its loading state rather than leaving another category's songs under the new label. Existing row animations and playback queues are preserved.

The old cache read still ran public Shorts HEAD probes. Mongoose's strict cache schema also discarded `durationSeconds`, so even long videos could be probed again after a server restart. The cache now retains optional duration metadata and a `shortsFiltered` flag. Fresh verified entries return directly until the existing one-hour expiry, including successful empty results. A legacy entry is filtered on its next read and only that derived cache entry is updated; its original `cachedAt` is retained, with an optimistic timestamp condition and no upsert. It does not extend old cache freshness or recreate expired records.

Search and statistics requests have explicit six-second and 2.5-second deadlines; Shorts probing retains its existing 3.5-second batch budget. Simultaneous identical requests share one pipeline within the current process. A cache write failure returns the fetched songs without repeating the YouTube search. Failed provider requests are never cached as successful empty lists.

The one-hour cache also bounds when unclassified Shorts are checked again; this remains a best-effort classifier, and unknown results are retained to avoid removing regular songs. Videos shorter than 2:30 remain eligible. Process-local deduplication does not coordinate different Vercel instances. Provider latency, first-use MongoDB connection setup and an uncached category can still take longer than a warm-cache response.

Only the derived SongCache schema and its normal cache writes changed. No business account, favorite, playlist, listening-history or SoundCloud record was edited by this work. No database reset, index synchronization or migration was run. No dependency or animation configuration changed.

## Evidence

- Before the change, a real Acoustic client navigation had an RSC request duration of 1186 ms and the whole category page waited for the feeds. Direct HTML requests to cached categories took 812–1630 ms in the initial sample.
- After the change, the selected category header updated in 89–93 ms in browser checks. A warm Acoustic RSC request took 78 ms. Three subsequent real HTML requests completed in 107, 72 and 68 ms, with first bytes in 54, 23 and 15 ms. These are local observations on this machine, not a hosted latency guarantee; initial legacy cache verification still takes longer.
- During first legacy-cache verification, rows completed independently: Acoustic Most Viewed was available around 945 ms while ranking/newest were still pending until about 1455 ms. The header had already updated at 89 ms.
- Desktop 1440 × 1000 and mobile 390 × 844 showed the correct category in all three headings without horizontal page overflow. Keyboard activation of Lofi Chill loaded the matching category and all three feeds completed with `aria-busy=false`.
- Seven cache regression tests failed before the fix; the independent-rendering regression also failed before adding Suspense boundaries. Final `npm test`: 137 passed, zero failed or skipped. Lint, production build and whitespace checks passed. Existing Shorts, playback, lyrics and animation regressions remain green.

The repository's tests exercise external HTTP boundaries deterministically, and browser measurements use real provider/cache results. Postman CLI/connected execution tools were unavailable in this session; no Postman run is claimed. The implementation follows the installed Next.js 16.4.3 streaming guide at `node_modules/next/dist/docs/01-app/01-getting-started/06-fetching-data.md`.
