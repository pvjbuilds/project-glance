# Glance 0.1.0 build 1: local release record

## Installed footprint and rollback

The coordinating session installed the local app at `~/Applications/Glance.app` and verified its bundled viewer, updater and guide match the build, plus the ad-hoc signature. This signature is local and is not Developer ID signing or notarization. This is not a public release.

The app's default data directory is `~/Library/Application Support/ProjectOverview/`: `store.json` is the current data, `store.backup.json` is the previous validated snapshot when one exists, and `.lock` coordinates writers. Preferences are in the `local.projectoverview.viewer` defaults domain (including selection and UI choices). The optional macOS login item is user-controlled; its behavior has not been verified.

To remove the app, quit Glance and remove `~/Applications/Glance.app`. That leaves saved projects and preferences intact. Removing the data directory deletes project data and its backup; preserve or export it first if it is needed. The app preferences can be removed separately with `defaults delete local.projectoverview.viewer` when the user wants that reset. If a login item was enabled, disable it in macOS settings. These are rollback instructions, not actions performed during this release.

The first attempted global router installation was rejected by automatic approval review before execution. After the user explicitly authorized installation for both assistants and one low-effort Haiku test, the coordinating session installed and verified `~/.agents/skills/project-glance` and `~/.claude/skills/project-glance` (mode 0600, guide references verified). Fresh sessions discovered the installed Codex and Claude routers, and an isolated low-effort Haiku session connected and updated the fixture. To remove a router later, remove only its `project-glance` directory after confirming it is the managed Glance router. The built-in Help prompt also points directly to the bundled guide.

## Review and tests

Independent local Codex source review passed within scope after fixes for strict numeric store validation, launch without a build directory and persistent Help navigation. This is the designated `solo:codex` review and shares same-provider blind spots. The reviewer did not independently rerun the complete test suite. The coordinating session reran the final native UI harness in the working desktop environment and observed its success marker, superseding the earlier inconclusive sandbox run.

The writer verified the build, ad-hoc signature, existing store tests, corruption and backup preservation, installer ownership and idempotence checks, and an isolated fake-launcher check. Twelve test-only instrumented writers were killed at four boundaries; each left a valid primary and backup, released the lock and allowed a version-checked follow-up update. This is process-interruption testing, not a simulated or actual power loss. An isolated fresh Codex guide-only enrollment test passed with one fixture entry at version 1. A second fresh Codex chat connected and updated the same fixture to version 3 with two associated sessions. A separate fresh Codex session verified installed skill discovery. The first Haiku harness attempt hid user skills and denied the updater and changed no data; the corrected authorized Haiku run loaded user skills with hooks disabled and empty MCP configuration, discovered the router, and connected and updated the same fixture to version 5 with three associations. Independent readback verified one entry and preserved the goal, name and checkpoint. Only the bundled guide and synthetic fixture were provided to Haiku.

Source snapshot SHA-256 at review handoff:

- `Sources/Store.swift`: `a07ebcb42882560639bf3e6068fab7a5ef0b53c1b0a8fbfbe14e14135147ba6c`
- `Sources/Viewer.swift`: `5d78802a8d6694e26de5fa28769d809c0412c720e7bf713f258198805a5365f6`
- `docs/agent/AgentGuide.md`: `a90054b959eb39e3758260e909d0e1f10334a48f44afb1889e8f0f55921391f9`
- `scripts/build.sh`: `506e9f2bdb6c520a1065cd176067408c07c00abae7136acd99e559ba90d9ec6d`
- `scripts/show.sh`: `eb1edab4e7c9e029d7c2042c5f9b01a9683f1e2b858e380055dc687c440c5d97`
- `scripts/install.sh`: `23bc6b7b92cd571fcb1999805203ef682283b9a20db73b11f757f83b84cb60ca`
- `scripts/install-agent-skills.sh`: `f9e5663e91f4ef67c36d3009de503193b0a440ff06be8c897f1974a4a531759b` (Codex-only option added and statically reviewed after app review; not bundled in app).

## Acceptance status

- **Verified within scope:** local bundle installed and compared; explicit enrollment and versioned updates in isolated tests; store corruption preservation and bounded interrupted-writer recovery; native UI harness including Help navigation; source review under solo mode; guide-only Codex enrollment and new-chat update; fresh Codex and Haiku skill discovery and isolated Haiku update.
- **Deferred or unverified:** actual power loss; login-item activation; sleep/wake, Spaces and full-screen behavior; multi-display and full accessibility; general compatibility across macOS versions; public distribution and notarization; universal behavior across future model or environment changes. A backup is read-only and is not automatically restored. After a write error the primary outcome can be uncertain; read it before retrying.
