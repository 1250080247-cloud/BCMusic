# Search suggestions and unrestricted durations — 2026-10-28

## Observable behavior

The search field opens a suggestion list immediately below the input while typing. Matching local history appears immediately and takes priority; online suggestions follow after a 300ms debounce for prefixes from 2 to 120 characters. Up to eight unique terms are shown. History matching ignores case and Vietnamese accent differences, while the original display text is retained. Ordinary search submission remains available for longer queries and when suggestions fail.

Arrow keys move the active option and scroll only the dropdown when necessary. Enter searches the selected term; Enter with no active option submits the typed term. IME composition does not trigger suggestion selection. Escape and leaving the field close the list. Choosing a term uses the existing `/search?q=…` flow and does not play a preview clip or change the playback queue. Clearing the field or changing the query cancels pending suggestion requests and prevents stale results from reappearing. Successfully loaded suggestions are reused when the same field is refocused, without a repeated-request loop.

The field exposes a combobox with a labeled listbox, selected options and `aria-activedescendant`. Labels are rendered as text, with no HTML insertion. Existing recent-search controls, video pagination, animations and full search remain in place.

## API contract and provider limits

`GET /api/search/suggestions?q=…&language=vi|en` returns `{suggestions: string[]}`. Empty/one-character prefixes return an empty array without contacting the provider. Prefixes above 120 characters, control characters or unsupported languages return HTTP 400. Input bounds apply to autocomplete requests, not song duration or the ordinary search field's ability to submit a longer query.

The server contacts only `https://www.google.com/complete/search`, with `client=firefox`, `ds=yt`, a locale and an encoded prefix. It uses a 2.5-second request timeout, rejects redirects, reads at most 65536 response bytes, verifies the returned query and accepts only bounded string suggestions. There is no API key or call to the YouTube Data API while typing. Successful upstream fetches revalidate after five minutes; successful endpoint responses cache for 60 seconds with stale-while-revalidate for 300 seconds. Errors return HTTP 200 `{suggestions: [], unavailable: true}` with `no-store`, allowing the UI to retain local-history suggestions and ordinary search.

This is a best-effort public autocomplete endpoint, not a guaranteed YouTube Data API contract. Availability or response formats may change. The Google `/complete/` endpoint family is represented in [Chromium's search configuration](https://github.com/chromium/chromium/blob/main/components/search_engines/search_terms_data.cc); the `firefox` / `ds=yt` response shape and Vietnamese results were verified live for this integration. A test of lyrics.ovh's Deezer-based `/suggest` returned unrelated artist matches for “biển”, so it was not used as the UI autocomplete source.

Only the currently typed prefix and locale are sent to Google. The user's local search history, account identity, cookies and credentials are not forwarded to that provider. No MongoDB read/write, model change, new dependency or environment variable is required by autocomplete. The existing streaming JSON limit helper was shared with the unchanged lyrics transport; all lyrics regressions pass.

## Duration and lyrics clarification

Video results now require a known duration strictly greater than 30 seconds, with no maximum. No `videoDuration=medium` or 2:30 threshold is applied. Shorts and unknown classifications are excluded, including timeouts or blocked probes. This supersedes the original one-second-video regression. Term suggestions themselves have no video duration. See [the current filtering contract](youtube-filtering.md).

lyrics.ovh's lyrics API accepts artist and title, not a genre filter. Its documentation does not define a fixed list of supported music genres; finding text depends on its available sources and metadata matching. It supplies plain text in this app, with LRCLIB remaining the primary source for recording-matched timing. See its [lyrics endpoint contract](https://github.com/NTag/lyrics.ovh/blob/main/apiary.apib) and [current source description](https://github.com/NTag/lyrics.ovh/blob/main/README.md).

## Verification

- `npm test`: 163 passed, zero failed or skipped. Coverage includes debouncing, canceled/stale responses, completed-result reuse, accent folding and deduplication, safe rendering, keyboard/IME behavior, fallback history, API validation and regular-video duration boundaries. The repeated-request guard was deliberately removed for a mutation check: its regression failed, and the original source was restored byte-for-byte.
- Full lint and production build passed. The added test after full lint also passed focused lint; whitespace checks passed.
- A live public-provider request for “biển” returned HTTP 200 in 287ms. The production API returned eight Vietnamese terms, including “biển tình” and “biển đảo và em remix”, with the configured response cache policy.
- Browser checks used the real production build through an isolated preview. Local history was seeded with a sample public term, autocomplete called the real backend/provider, full video-result requests were replaced with an empty test fixture, and HTTP writes were blocked. No playback or real library mutation was performed.
- At a 1280px desktop viewport, typing displayed matching history immediately, followed by eight merged suggestions. Eight ArrowDown presses selected the last option; its dropdown scrolled 32px and the active option was visible while input focus remained on the combobox. Enter navigated to the selected full query. A pointer selection also navigated correctly. Clearing closed the list and restored the normal history view.
- At 320px width, the dropdown stayed within the page (right edge 210px), with no horizontal overflow. Escape set `aria-expanded=false` without clearing the typed text. The temporary viewport override was reset afterward. Browser error logs were checked separately.

Postman skills guided contract/testing choices; Postman execution tools were unavailable, so no Postman run is claimed. Implementation and screenshots are local verification artifacts; no GitHub push or Vercel deployment was performed for this change.
