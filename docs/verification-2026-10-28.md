# Verification — 2026-10-28

## Delivered behavior

- Selecting a home category applies it to Top Trending, Most Viewed and Newest. Most Viewed uses `viewCount`, Newest uses `date`, and Top Trending uses relevance for the category plus the search term `trending`. This is a category-specific discovery feed, not an official YouTube chart. Old TikTok links containing the unrelated `ncs` suffix resolve to `tiktok remix`.
- The music player uses the cover as its blurred background, with existing controls and a lyrics/queue/details view. LRCLIB supplies line timestamps when the title, artist and recording duration match. Plain lyrics and explicit unavailable/error states cover other cases. Word/syllable timestamps are not invented. No lyrics are persisted into MongoDB.
- Search and recommendations no longer request YouTube's `medium` duration filter. Confirmed Shorts are excluded while regular songs shorter than 2:30 remain eligible. Public Shorts routing is a best-effort classifier: blocked requests and timeouts preserve unclassified results rather than discarding ordinary songs.

## Automated checks

| Check | Result |
| --- | --- |
| `npm test` | 129 passed, 0 failed, 0 skipped (after the lyrics follow-up below) |
| `npm run lint` | Passed |
| `npm run build` | Passed with Next.js 16.4.3 |
| Full `npm audit --json` | 0 vulnerabilities |
| `npm audit signatures` | 393 registry signatures and 92 attestations verified |
| Clean installation with lifecycle scripts disabled | 393 packages installed successfully |
| Native Sharp image processing | In-memory WebP smoke check passed |
| `git diff --check` | Passed |

Regression coverage includes all three category queries, category pagination, short regular videos, Shorts redirects, unknown classifications and bounded network time; canceled/stale lyric requests, LRC parsing and recording matching; player keyboard seeking, focus restoration and recording-scoped playback errors; existing playback/queue behavior and patched authentication behavior.

## MongoDB checks and data preservation

The existing connection URI and business schemas were retained. No migration, database reset or index synchronization was run. The previously completed real CRUD check used temporary records and removed only those records; the final verification used read-only ping, API reads and document/index hashes.

Production reads of `/api/playlist`, `/api/soundcloud/import`, `/api/history` and `/api/auth/session` returned HTTP 200. MongoDB ping succeeded with the configured DNS fallback.

User (4), Playlist (9), Favorite (7) and SoundCloudTrack (7) counts and document hashes were identical before and after the final verification. All five collections' index hashes were unchanged. History increased from 232 to 233 during concurrent application usage: excluding the single additional record reproduced the exact original digest, confirming that all 232 existing history documents were unchanged. The added record did not reference the UI fixture's video ID and was retained. Browser tests intercepted write requests and did not insert their player/lyrics fixtures into MongoDB.

## Browser and provider evidence

- Real home navigation between TikTok Remix and Chinese Music changed all three section labels and feeds together. The final TikTok screenshot uses real provider results.
- Desktop (1440 × 1000) and mobile (390 × 844) player layouts showed the cover, controls and queue without horizontal overflow. Reduced-motion preference disabled the focus-player animations.
- Escape closed the native dialog, restored body scrolling and returned keyboard focus to the opener. The mounted media element remained available. The error-message check showed the message only for the current recording and cleared it when the controller reported recovery.
- A deterministic lyrics screenshot uses five original Vietnamese test lines and controlled media-time events. It proves active-line rendering and seeking UI behavior; it is not evidence of streamed audio or real lyrics for the pictured cover.
- Real LRCLIB lookup returned HTTP 200; invalid metadata returned 400. Coverage, completeness and latency depend on LRCLIB. Partial records and timeouts were observed and are handled by fallback/error states.
- Live Shorts probes distinguished a known Short from a known 19-second regular video. This establishes the observed routing behavior, not a permanent provider guarantee.
- Two real YouTube test recordings displayed “This video is unavailable” in the test browser. Actual audio playback could not be confirmed in that environment; the player now reports the error instead of leaving a misleading playing state.

Postman skill routing was followed. Neither a Postman CLI nor connected Postman execution tools were available in this session, so API evidence comes from real HTTP requests and the repository's automated boundary tests; no Postman collection execution or publication is claimed.

The production server was left running locally at `http://127.0.0.1:3100`. No Vercel deployment was performed.

## Follow-up: lyrics for the reported Hngle / Bảo Anh recording

The reported title was `Hngle - Tìm em ft. Bảo Anh | Official Music Video`. The old metadata helper left the featured artist and video label inside the track name. Live LRCLIB direct requests with that metadata returned HTTP 503 `ServerOverloaded`; the old lookup propagated that error without attempting search. Searching the clean track title and lead artist returned matching plain and synchronized records, with credits expressed in several layouts.

The fix cleans presentation metadata, preserves the full collaboration credits, permits a separate bounded search after transient direct failures, and considers synchronized search results even when the direct result has plain lyrics. Five new reproduction cases failed before the change; all six new regression cases and all 129 repository tests passed afterward. Lint and production build passed. The response contract, MongoDB configuration, database schemas, stored songs and animation code were not changed.

Live verification on the new production server returned HTTP 200 `synced` for the reported title's normalized metadata. In the browser, the actual YouTube recording supplied duration 273 seconds and the real LRCLIB response rendered 50 timed lines. Without injected media-time events, the playback position advanced from 69.1 to 71.1 seconds. Clicking a lyric requested 51.76 seconds and the displayed playback position became 51.8 seconds, with exactly one active lyric line. No horizontal overflow was present. Browser write requests were intercepted; the lyrics lookup itself never reads or writes MongoDB. Network timeouts were also observed during diagnostics; an ongoing upstream outage still produces the retry state rather than fabricated lyrics.

## Remaining runtime notices

The existing SongCache schema declares `cachedAt` twice as an index; Mongoose also reports the existing history route's `new` option as deprecated. They are separate from the resolved dependency audit findings. No schema/index change was made during this verification.

## Provider references

- [YouTube search duration filters](https://developers.google.com/youtube/v3/docs/search/list#videoDuration)
- [YouTube Shorts duration guidance](https://support.google.com/youtube/answer/15424877)
- [LRCLIB project and API](https://github.com/tranxuanthang/lrclib)
