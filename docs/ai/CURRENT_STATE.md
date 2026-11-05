# Current state

As of 2026-11-06, Asia/Kolkata. Writer: Codex implementation agent; next reviewer: independent reviewer for later material changes. Canonical checkout is this folder; the local `master` branch has a private remote verified by the coordinating session; the 5 November refinement passed local source review within its stated scope.

## Objective and checkpoint

Validate a local native menu-bar popover and explicit-enrollment shared store. This is a bounded local pilot, not a public release. Project Glance itself is the sole explicitly enrolled pilot item, stored outside the repository and associated with the explicitly connected Codex session. No global assistant integration, app installation, launch-at-login setting or account was configured.

## Prototype and evidence

`scripts/build.sh` compiles the app and CLI into ignored `build/` using the installed Swift toolchain. `python3 tests/store.py` checks explicit enrollment, repeat request, association, stale revision, eight concurrent update processes, invalid IDs and malformed records. One JSON envelope holds one logical record per ID, association metadata and the directory; writers use `flock` and atomic replacement. This removes the two-file partial-enrollment window. A same-ID, same-request retry is idempotent; request IDs cannot create a second project. Atomic replacement has not been tested against power loss and does not establish fsync durability. Session association is a workflow guard, not authentication against other local processes.

The app is a local pilot; repositioning, multi-display recovery, wake, full-screen/Spaces and accessibility require further desktop tests. Full-screen and Spaces behavior are unverified. A status-backed Open at Login menu action is implemented but has not been exercised; nothing was registered. Freshness updates each minute and marks seven-day-old records stale. A file watcher reloads the envelope; an in-memory last-valid snapshot is retained when reading fails. Missing and invalid records must not be represented as complete. On 2 November, the parent tested the earlier floating-panel app against its default store; those historical checks do not establish behavior of the 5 November popover. The parent then verified the window opens, its live watcher refreshes on enrollment and update, the four priority fields fit the card, the selector works, Command-Q quits, and the floating panel remains visible over Finder on an ordinary desktop. An isolated demo confirmed duplicate names select distinct checkpoints, long-content scrolling reaches the footer, close hides without quitting, reopen restores the selected project, and displayed age advances without agent updates. See [native validation](reviews/2026-11-02-native-validation.md). The first launch was not isolated; only this project was enrolled afterward. Other native checks remain in progress.

## Review packet

Claude Opus 5.5 returned **passed-within-scope (cross-provider)** for the bounded local pilot source and architecture recheck on 2026-11-02; see [review record](reviews/2026-11-02-claude.md). This is not a public-release or desktop pass. Claude verified native `CLAUDE.md` import of the shared contract, but did not test hooks. Diagram automated rendering gates passed; it was not visually reviewed. The later file-context safety fix was build-checked and reviewed in source by the parent; the reveal action was not desktop-tested and was outside Claude’s reviewed Viewer hash. Earlier rendering receipts remain ignored; the separately ignored recheck folder contains the later evidence. A1–A3 remain open for untested lifecycle and recovery behavior.

## Next action

Complete the remaining native lifecycle checks when practical and decide whether to install any global integration through the appropriate owner. Preserve explicit enrollment and review boundaries. Maintain current source and state together. No global integration until separately authorized.

## 2026-11-05 menu-bar redesign

The screenshot-style menu-bar popover is built. Structured read-only milestone checklists accept only unique IDs and JSON booleans; legacy records do not acquire invented completion. The build, expanded store checks and local skill validation passed. The coordinating session explicitly updated the sole real Project Glance record to version 7 with five completed and two pending milestones, and verified the revised app process was running. This establishes saved data and process presence, not menu-bar interaction.

See [rendering validation](reviews/2026-11-05-render-validation.md) for capture methods, hashes and the image-preview transport issue. Actual anchor, dismissal, login, wake and full-screen/Spaces interactions remain unverified. The 5 November source review passed within scope in a fresh local Codex session; see [local review](reviews/2026-11-05-codex.md). Same-provider review shares blind spots and is not cross-provider review; the earlier cross-provider review covers only the 2 November snapshot. No global agent skill or hook is installed.

## 2026-11-06 explicit show action

`scripts/show.sh` launches the built app with `--show`; reopening requests show rather than toggle the popover. Ordinary startup stays silent. A separate native QA bundle with an isolated missing store reported initial show, repeated show and reopen all true, and silent startup true. The parent delivered a reopen request to the previous built app but did not claim visual confirmation. The parent verified the final default bundle ran with `--show` and invoked the show script successfully; actual screen visibility and user click interactions remain unverified. A fresh Codex reviewer passed an activation-only source review without findings, with same-provider blind spots; it did not rerun the native test. See [show validation](reviews/2026-11-06-show-validation.md).

## 2026-11-06 nested milestone refinement

The candidate adds bounded nested checklist data, explicit current-branch expansion, per-project disclosure choices, optional scoped token estimates, a compact summary and a monochrome menu-bar icon. The coordinating session explicitly updated the sole live record to version 8: five of eight top-level milestones complete, with the current refinement branch and one pending user layout check. A fresh independent local Codex source/design review passed within scope after a picker-refresh fix; same-provider blind spots apply. See [review](reviews/2026-11-06-nested-review.md). The coordinating session launched the rebuilt default app with `--show` and verified the process; native visibility, menu-bar interaction and lifecycle behavior remain unverified. The version-8 content render is a local review artifact.
