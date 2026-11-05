# Explicit show validation — 2026-11-06

Viewer source SHA-256: `4b57209a244d31aa268ab1049a4a7dba2638aaf3fd25576c12d565a9521d0202`. `scripts/show.sh` opens the built app with `--show` and reports a missing build without installing anything. The code retries briefly while the status item initializes; repeated show or an application reopen requests show, never toggle closed. Ordinary launch without `--show` is silent.

The canonical app and updater compiled, and the store test suite passed. A separate test bundle, derived from this source and instrumented only to report state, used a nonexistent isolated temporary store. After startup it reported `initial=true repeated=true reopened=true` with `--show`; a second launch without it reported `silent=true`. The missing-build script check returned a clear error and exit 1. The parent separately invoked the previous built app's reopen path but did not visually confirm the result.

This is an AppKit state check, not a verified LaunchServices delivery to an already-running final build or a visual confirmation of the popover. Menu-bar click, screen visibility and lifecycle behavior remain unverified. The 5 November independent local source review predates this source change and does not cover it.

A fresh independent Codex reviewer passed an activation-only source review with no findings. It reviewed the Viewer hash above and `scripts/show.sh` SHA-256 `b39518babf17f7f755a0afc8428fb80ffcd91cc8fc594854931cee936ecfc0a4`; it did not rerun the native test. Same-provider review shares blind spots. The parent replaced the previous app process and verified that the final default bundle ran with `--show`, then invoked the LaunchServices show script successfully. No screen visibility verdict was made.
