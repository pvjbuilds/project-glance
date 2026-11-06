# Project

## Purpose
A native macOS menu-bar application with an anchored popover for a deliberately small set of explicitly enrolled projects. Show the overall project goal, checkpoint, status, milestone progression, blocker or next unlocking action, estimated remaining effort, sources and freshness. The working name Glance is provisional.

## Boundaries
No machine-wide discovery, automatic enrollment, backlog import, model polling, cloud service, mobile application or task manager. Each enrolled project has one canonical status record, and only explicitly associated sessions may update it. Never move existing projects. Live data stays outside the source repository.

## Architecture
An AppKit menu-bar process displays an anchored transient popover and watches local state. A small local CLI provides explicit enrollment, association and version-checked serialized atomic writes. One local JSON envelope maps stable project IDs to canonical logical records and session associations; any cache is derived. A status-backed, optional launch-at-login menu action is implemented but untested and never silently enabled. The 5 November refinement passed a separate local source review within its stated scope; native lifecycle behavior remains unverified.

## Setup and checks
Swift 6.3.3 and the Command Line Tools SDK were detected on 2 November 2026. Run `scripts/build.sh` and `python3 tests/store.py`; dependencies have not been installed. The 2 November prototype passed cross-provider source review within its recorded scope. The 5 November refinement passed a fresh local Codex source review, which shares same-provider blind spots.

## Success and protection
A launchable local pilot shows persisted selected-project state, distinguishes closing the popover from quit, recovers after wake, and reports stale or unavailable sources honestly. Test explicit enrollment, conflict handling, malformed and missing data. The local app installation was authorized and completed; no login change was made. The initial global skill installation attempt was rejected by automatic approval review before execution; after explicit authorization, the Codex and Claude skill routers were installed. Fresh-session discovery checks passed for both routers; updates still require an authorized associated agent. A private remote exists; further native lifecycle verification remains open.

## 2026-11-06 local release
Version 0.1.0 build 1 is installed at `~/Applications/Glance.app`; the ad-hoc signature is not Developer ID or notarization. Explicit enrollment and session association remain required. See [release review and footprint](reviews/2026-11-06-release-review.md) for verified checks and remaining limits.
