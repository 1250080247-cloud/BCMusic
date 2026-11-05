# BCMusic 1.2.0

## Reference and scope

Adapt the user-provided `Thiết kế ứng dụng BCMusic/src/App.tsx` and `src/index.css` into the existing Flutter application. The reference is a React visual prototype with fixture songs, local-only authentication simulation and placeholder controls. It is design input, not production code or a new backend.

Use the ui-ux-pro-max skill from the user's `.codex/skills` directory. Its dark entertainment style guidance fits this product; the suggested marketing page pattern, green accent and alternative typography do not fit the supplied design. The reference's neutral palette and existing Android typography take precedence. Flutter LayoutBuilder, semantic controls, 48dp buttons and reduced-motion handling apply.

## Implemented

- Neutral dark/light theme, white/dark high-contrast Play buttons, bordered cards and rounded sheets.
- Compact header with existing BCMusic logo, real account avatar, authentication menu and settings.
- Compact vinyl hero with working Play action, genre chips, horizontal trending cards, ranked popular songs and recent song rows.
- Offline library storage summary calculated from actual track bytes; existing download/retry/remove controls retained.
- Playlist cover grid and detail cover collage using locally cached artwork.
- Rounded mini player, disc artwork and larger Play control in the expanded player, plus explicit offline/online status.
- Version 1.2.0, Android versionCode 5. Same application ID and signing setup for updates preserving local data.

## Deliberate boundaries

Do not copy placeholder songs, fabricated download counts/storage quotas, simulated sign-in or inactive buttons from the reference. History, favorites, repeat/shuffle, system theme and SoundCloud search require separate functional work; existing supported controls remain available. SoundCloud retains link import and offline library functionality. Google authentication still requires the previously implemented web endpoints to be deployed.

## Validation

Run `tool/bcmusic.ps1 check` and `tool/bcmusic.ps1 build`. Flutter layout tests cover all five tabs and settings in both themes at 375x812, 812x375 and 800x1100 with 2x text. Physical-device installation is conditional on an authorized ADB connection.
