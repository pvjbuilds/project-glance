# Menu-bar rendering validation — 2026-11-05

The reviewed content view is `Sources/Viewer.swift` SHA-256 `0964dfeedf922b7bbe7320e50171dae29599fd8ddb6914c3db5839a2357f974a`. The updater is `Sources/Store.swift` SHA-256 `33676795bed1d65e76b198b36aebe2bd2739031120947f9687e8f1edcaa633a6`. These identify the candidate captured before it was committed in `53536c7`.

A native self-test briefly mapped the app's own clearly labelled fictional windows, then rendered the production content view at 1x and 2x. Each fixture ran in a fresh process. Main, legacy and long-content views used populated `CALayer.render(in:)`; the empty view used `NSView.cacheDisplay`. The long-bottom image was programmatically scrolled; no computer-use control or live project data was used. The captures are ignored build artifacts under `build/previews/final-pass/` and are not committed.

The image preview transport sometimes displayed stale or incorrectly composited copies of PNGs. The parent checked the actual PNG pixels and alpha and viewed fresh JPEG conversions; these confirmed header and footer presence and long-content clipping in the rendered artifacts. The conversions are review aids, not replacement source captures. This is evidence of production-view rendering and programmatic scroll, not of real menu-bar popover interaction or a user-driven scroll test.

The actual status-item click, native popover anchor, outside-click dismissal, Escape, login item, sleep/wake and full-screen/Spaces behavior remain unverified for this revision. Settings is a native alert and was not captured. Independent cross-provider review of the 5 November revision is pending; the 2 November review applies only to its recorded earlier revision.
