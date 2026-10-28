# YouTube discovery filtering — 2026-10-28

## Contract

- Home rankings, most-viewed, newest, search and Explore share `getYouTubeSongs`.
- A result must have a finite known duration strictly greater than 30 seconds. Exactly 30 seconds, missing duration and invalid metadata are excluded. There is no maximum duration.
- Confirmed Shorts, invalid IDs and unknown classifications are excluded. Timeouts, 403/429 responses, consent/challenge pages, redirects to another video and exhausted probe budgets never admit an unchecked candidate.
- YouTube currently documents Shorts up to three minutes: [YouTube Help](https://support.google.com/youtube/answer/15424877?hl=en). Videos longer than 180 seconds do not require a Shorts probe. Candidates up to 180 seconds require a same-origin `/watch?v=<same-id>` redirect from the public Shorts URL.
- Public URL routing remains an unofficial classifier; the app conservatively hides anything it cannot verify. Lists may contain fewer items or be empty during upstream blocking.
- Real next/previous pagination tokens are preserved after filtering. Keyword autocomplete remains a separate term-only service.

## Cache and data

`shortsFilterVersion: 3` certifies the strict policy. The old boolean alone is insufficient. Old cache entries are rechecked on read, and complete classification updates only derived song-cache fields with the original expiry and an optimistic timestamp condition. No bulk migration, cache purge or changes to accounts, history, favorites or playlists are required.

The duration cutoff is reapplied even to current verified cache entries, without mutating the read object or rewriting data just to enforce that cutoff. Old rows without duration stay hidden until normal refresh supplies metadata.

Incomplete Shorts checks do not certify or overwrite an old cache entry, nor cache a fresh partial page for an hour. Unknown process-local classifications are retried after 30 seconds; known classifications expire after 24 hours. Fresh duration-metadata failures return no unchecked items and are not cached as successful empty pages. Successful fully classified empty pages remain cacheable. Internal completeness metadata is never exposed in the response.

## Verification

Regression tests run application modules with provider/cache boundaries replaced by deterministic fixtures. They cover duration boundaries, 26-hour recordings, fresh and both old/current cache reads, confirmed Shorts longer than 30 seconds, upstream blocking/timeouts, exhausted budgets, retry recovery, pagination and unchanged read objects/expiry. Postman CLI and execution tools were unavailable; no Postman run is claimed.

The older verification and category-performance notes describe the prior lenient policy. This contract supersedes their statements about retaining unclassified videos or imposing no minimum duration.
