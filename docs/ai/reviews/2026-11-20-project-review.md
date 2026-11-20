# Glance project review · 20 November 2026

## Release position

The public MIT repository ships source alphas v0.2.1 and v0.2.2. At the start of this review, local master, remote master and the peeled v0.2.2 tag all resolved to `ab43b6a7d2011ab0f51bd1a8cc78b746415c106e`. The installed version was 0.2.2 build 5. Both hosted runs for that revision passed. The remote had no open issues or pull requests. Git verified the ten relative files linked from the README, including LICENSE. [Published release](https://github.com/pvjbuilds/project-glance/releases/tag/v0.2.2) · [Hosted checks](https://github.com/pvjbuilds/project-glance/actions/runs/42301410667)

Nine of ten improvement items have shipped locally. Glance displays opted-in projects, their latest checkpoint, health, freshness, milestone branches, completion evidence, recurring work, and optional effort and usage details. The all-projects view and agent guides are present. The CLI coordinates explicit session association, version-checked writes, read-only listing and operator-directed backup recovery. The project is at source alpha. The signed-binary distribution path and broader desktop acceptance remain separate work.

## Click-away dismissal

The reported problem occurs after opening the popover from the menu bar. The released viewer used AppKit's transient popover and only its built-in dismissal policy. Apple documents that some outside interactions can leave a transient popover open. An accessory app's active or key state is a plausible contributor. The review did not establish it as the only cause. [Apple's transient behavior reference](https://developer.apple.com/documentation/appkit/nspopover/behavior-swift.enum/transient)

The 0.2.3 patch retains AppKit's transient behavior and adds mouse-down observers for the lifetime of the visible popover. Outside events dismiss Glance while continuing to the clicked application. The popover and its own menu-bar button retain their existing interaction paths. The patch requests no app activation and uses no global key monitoring. [Apple's event monitoring reference](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/EventOverview/MonitoringEvents/MonitoringEvents.html)

## Council and decisions

Opus 5.5 medium independently reviewed an isolated subset of public revision `ab43b6a`, then reviewed the proposed passive-click diff. Opus first suggested activating Glance as well as monitoring clicks. Sol favored preserving foreground focus. Opus accepted the passive design on the second round, subject to guarding late show callbacks, cleaning up on close and recording desktop acceptance. Opus performed source review only. The subset omitted the licence and documentation images, which were verified separately against the public commit. We retained the intentional behavior where associating another chat advances the revision without changing the content-save time.

## Remaining work in order

| Priority | Work | Completion evidence |
| --- | --- | --- |
| 1 | Validate the real menu-bar flow, then close the existing Mac reliability item | Click another app, the desktop and another menu-bar item. Confirm the next click reopens Glance, rapid toggles behave, picker and Settings work, and repeat on sleep/wake, Spaces, full-screen and an external display. Check keyboard and VoiceOver. Test login launch only as a deliberate opt-in. |
| 2 | Make acceptance repeatable for contributors | Provide one documented invocation for the seven hosted suites, alongside a clearly separate desktop test. Keep missing desktop evidence distinct from a pass. |
| 3 | Prevent viewer and CLI validation drift | Run the same accepted and rejected record fixtures through both implementations. Review making schema 2 the default for new stores after testing onboarding, update-token readback and older-reader compatibility. Keep existing-store migration explicit. |
| 4 | Define the beta distribution and support baseline | Pin the supported build target and test the oldest claimed macOS. Publish a source beta when the desktop matrix passes. Decide on Developer ID and notarization if shipping downloadable binaries. |
| 5 | Optional product polish | Evaluate whether a compact all-projects health layout and clearer saved-age wording help at higher project counts. The README GIF still awaits approval of the shown candidate. |

Store tests cover atomic writes, conflicts, recovery, malformed data and permission boundaries. The process-interruption checks exercise kill/restart boundaries. Physical power-loss durability remains untested. A source beta does not depend on automated discovery, background models or remote sync.

## Verification

The logged-in AppKit harness passed on macOS 26.6.2. Synthetic in-app events passed through AppKit and exercised the outside dismissal path, inside click preservation, icon handling, fast close and monitor cleanup. The first harness assertion ran before the show callback. The final harness waits for the native lifecycle and fails if the success marker is missing. It does not simulate system-wide clicks. The test runner did not have macOS event-posting permission.

All seven non-UI suites passed. The installed 0.2.3 build 6 matched the locally built viewer, updater, guide and plist. The app signature verified and the process relaunched. The first immediate relaunch returned LaunchServices error -600. A separate open after the old process cleared succeeded.

| Symptom | Cause or observed boundary | Check or recovery |
| --- | --- | --- |
| Glance remains visible after an outside click | Platform transient dismissal alone does not cover every accessory app interaction | Validate the installed build from the real menu-bar icon and click another application. |
| UI runner exits zero without running assertions | AppKit can fail to connect to the desktop before the checks execute | The harness now requires its success marker. Run it in the logged-in desktop environment. |
| Immediate open after replacing and stopping Glance returns -600 | Observed around process exit while LaunchServices clears the old instance | Wait for the old process to exit, retry open, and verify a new process. |

Reviewed and locally tested Viewer SHA-256 `faa2c34f12fafbe817efd293c59234cd7a239450cc73c8446acfaf5f1acda1ad`. Opus reviewed the passive diff and proposed the lifecycle guard before this final snapshot. The coordinator checked the final source diff and ran the final native harness.
