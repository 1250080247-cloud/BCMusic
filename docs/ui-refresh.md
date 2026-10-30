# BCMusic UI refresh — 2026-10-30

The UI/UX Pro Max searches used `music streaming immersive discovery --design-system`, `dragging movements carousel --domain ux`, and `interactive client components --stack nextjs`.

Applied: the entertainment/OLED style's restrained surfaces, readable contrast, content hierarchy and visible focus; the dragging guideline's button and keyboard alternatives; leaf client components from the Next.js guidance. The generated marketing-page structure, green CTA and replacement fonts do not fit the existing listening app, so the current content architecture, pink identity, Geist font, light theme and 3D turntable remain the basis.

The refresh updates shared theme surfaces/navigation, the home search shortcut, section hierarchy and discovery cards. Categories stay on one scrollable row. Artwork, title, artist and views have distinct emphasis. Preview and play are native buttons; play works without hover on touch devices and is exposed on keyboard focus. Empty states explain what the listener can do.

## Carousel fix

The old ranking row had `cursor: grab` but no drag handlers. The new shared carousel serves ranking, most-viewed and newest sections. Mouse/pen drags scroll horizontally after a 6px threshold; clicks after a drag are suppressed, and a subsequent normal click still opens details. Touch uses native scrolling. Visible 44px arrow buttons, a focusable named region and ArrowLeft/ArrowRight/Home/End supply alternatives. Pointer capture, cancellation, scroll-edge state, resize cleanup and reduced-motion behavior are covered by regression tests. Existing GSAP list reveals remain scoped inside the viewport.

No API, MongoDB record, dependency or audio-controller changes are needed.

## Verification

- `npm test`: 178 passing tests; `npm run lint` and production `npm run build` passed.
- Production UI through an isolated localhost proxy with user-data writes blocked: mouse drags scrolled left and right (424px forward; 466px back to 0), without opening details. A normal click and keyboard Enter after dragging both opened the expected preview.
- Native touch emulation scrolled the row 165px without opening details. ArrowRight/Home/End and visible arrow controls were checked; reduced motion disabled decorative transitions while keyboard scrolling remained usable.
- At 320, 375, 768, 1024 and 1440 CSS px, the page stayed within the viewport. The mobile brand/actions no longer overlap, and all five bottom-navigation items fit. Light/dark themes were inspected; browser console showed no errors.
- Screenshots: `bcmusic-refresh-desktop-final.png`, `bcmusic-refresh-mobile-final.png`. These changes are local and have not been deployed.
