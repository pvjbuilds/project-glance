# Current state

As of 2026-11-02, Asia/Kolkata. Writer: Codex implementation agent; next reviewer: independent reviewer for later material changes. Canonical checkout is this folder; the local `master` branch has an initial commit; no remote exists.

## Objective and checkpoint

Validate a local native menu-bar and floating overview plus an explicit-enrollment shared store. This is a bounded local pilot, not a public release. Project Glance itself is the sole explicitly enrolled pilot item, stored outside the repository and associated with the current Codex session. No global assistant integration, app installation, launch-at-login setting or account was configured.

## Prototype and evidence

`scripts/build.sh` compiles the app and CLI into ignored `build/` using the installed Swift toolchain. `python3 tests/store.py` checks explicit enrollment, repeat request, association, stale revision, eight concurrent update processes, invalid IDs and malformed records. One JSON envelope holds one logical record per ID, association metadata and the directory; writers use `flock` and atomic replacement. This removes the two-file partial-enrollment window. A same-ID, same-request retry is idempotent; request IDs cannot create a second project. Atomic replacement has not been tested against power loss and does not establish fsync durability. Session association is a workflow guard, not authentication against other local processes.

The app is a local pilot; repositioning, multi-display recovery, wake, full-screen/Spaces and accessibility require further desktop tests. Full-screen and Spaces behavior are unverified. A status-backed Open at Login menu action is implemented but has not been exercised; nothing was registered. Freshness updates each minute and marks seven-day-old records stale. A file watcher reloads the envelope; an in-memory last-valid snapshot is retained when reading fails. Missing and invalid records must not be represented as complete. The parent launched the app against its default store, verified the window opens, its live watcher refreshes on enrollment and update, the four priority fields fit the card, the selector works, Command-Q quits, and the floating panel remains visible over Finder on an ordinary desktop. An isolated demo confirmed duplicate names select distinct checkpoints, long-content scrolling reaches the footer, close hides without quitting, reopen restores the selected project, and displayed age advances without agent updates. See [native validation](reviews/2026-11-02-native-validation.md). The first launch was not isolated; only this project was enrolled afterward. Other native checks remain in progress.

## Review packet

Claude Opus 5.5 returned **passed-within-scope (cross-provider)** for the bounded local pilot source and architecture recheck on 2026-11-02; see [review record](reviews/2026-11-02-claude.md). This is not a public-release or desktop pass. Claude verified native `CLAUDE.md` import of the shared contract, but did not test hooks. Diagram automated rendering gates passed; it was not visually reviewed. The later file-context safety fix was build-checked and reviewed in source by the parent; the reveal action was not desktop-tested and was outside Claude’s reviewed Viewer hash. Earlier rendering receipts remain ignored; the separately ignored recheck folder contains the later evidence. A1–A3 remain open for untested lifecycle and recovery behavior.

## Next action

Complete the remaining native lifecycle checks when practical and decide whether to install any global integration through the appropriate owner. Preserve explicit enrollment and review boundaries. Maintain current source and state together. No global integration until separately authorized.
