# Playlist artwork and lyrics backup — 2026-10-28

## Playlist behavior

The supplied reference has a narrow playlist list and a generic music icon. The list now uses the existing design system in a 1152px maximum-width container with larger title/controls. Each cover is 112px on desktop and 80px on small screens. Four latest-added songs form a 2 × 2 cover; one song uses a single image, and missing/broken images use the existing music icon.

The existing playlist API appends added songs. `PlaylistArtwork` derives its cover with a copied slice in reverse order and never reverses the original playlist. Playback still starts at the first song in the original queue. No new playlist property, schema, write endpoint or artwork file is stored in MongoDB. Removing/adding a song through the existing UI naturally recalculates the displayed cover.

## Lyrics backup

LRCLIB remains primary. lyrics.ovh supplies plain lyrics only after LRCLIB has no usable result or errors; usable synchronized, plain and instrumental LRCLIB results keep priority. Its public endpoint requires no API key. The normal API route and response shape remain compatible; the additional source identifier is `lyrics.ovh`. Provider attribution is displayed from a fixed URL allowlist, and no artificial word or line timings are produced.

Requests use fixed HTTPS hosts, encoded title/artist segments, denied redirects, bounded timeouts, a streamed 512000-byte response limit and an 80000-character text limit. Full artist credits and recording labels are retained in backup requests. The backup response has no independent recording metadata, so matching remains dependent on its upstream quality and does not guarantee coverage of every video. See [player-lyrics.md](player-lyrics.md) for fallback/error/cache rules.

## Verification

- `npm test`: 152 passed, zero failed or skipped. Seven new lyrics-fallback/UI cases failed before integration; playlist selection, missing artwork, broken-image recovery, UTF-8 chunk decoding, oversized streams, fixed origins and dot-segment guards are covered.
- `npm run lint`, `npm run build` and `git diff --check`: passed.
- Live lyrics.ovh probes for Coldplay, Hngle and Daft Punk returned HTTP 200 with nonempty lyric text. No lyric text from those songs is copied into this repository or report.
- An actual API route invocation used a local HTTP server to return controlled LRCLIB 503 responses, then the real lyrics.ovh endpoint. It returned HTTP 200, `plain`, source `lyrics.ovh`, 1188 text characters and zero timed lines. This proves live backup recovery under a controlled primary outage, rather than claiming that LRCLIB was unavailable for that song in production.
- The real production build was opened through an isolated, read-only UI preview. Only its playlist and lyrics responses were replaced with test data; all writes were blocked. At a 1280px desktop viewport, the playlist card measured 1088px and its cover 112px. Four real thumbnail images loaded in newest-added order. Both light and dark themes were checked.
- At a 320px viewport, the card measured 273px and the cover 80px; all six original-order test songs remained visible when expanded, with no horizontal page overflow. Enter expanded/collapsed the playlist and `aria-expanded` reflected its state. The temporary viewport override was reset afterward.
- The player displayed source `lyrics.ovh`, the original test text and the plain-lyrics caption with zero timed lyric buttons. This UI fixture does not claim actual source lyrics for the displayed cover. The YouTube test embed reported an unavailable recording; audio playback was not required or established by this preview.

No database writes were forwarded during browser verification. The new provider code does not import MongoDB/models. Database configuration, model files, playlist APIs, GSAP components, animation styles, package manifests and lockfile are unchanged. No dependency or environment variable was added. Postman skills guided contract/testing choices, but CLI and connected Postman execution tools were unavailable; no Postman collection run or publication is claimed.

Verification and screenshots were completed locally before publishing. No manual Vercel deployment was run.

Primary provider references: [API contract](https://github.com/NTag/lyrics.ovh/blob/main/apiary.apib), [provider source and API description](https://github.com/NTag/lyrics.ovh).
