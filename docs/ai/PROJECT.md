# Project

## Purpose
A native macOS menu-bar application with an anchored popover for a deliberately small set of explicitly enrolled projects. Show the overall project goal, checkpoint, status, milestone progression, blocker or next unlocking action, estimated remaining effort, sources and freshness. The working name Glance is provisional.

## Boundaries
No machine-wide discovery, automatic enrollment, backlog import, model polling, cloud service, mobile application or task manager. Each enrolled project has one canonical status record, and only explicitly associated sessions may update it. Never move existing projects. Live data stays outside the source repository.

## Proposed architecture
An AppKit menu-bar process displays an anchored transient popover and watches local state. A small local CLI provides explicit enrollment, association and version-checked serialized atomic writes. One local JSON envelope maps stable project IDs to canonical logical records and session associations; any cache is derived. A status-backed, optional launch-at-login menu action is implemented but untested and never silently enabled. Details and failure handling require independent review before implementation.

## Setup and checks
Swift 6.3.3 and the Command Line Tools SDK were detected on 2 November 2026. Run `scripts/build.sh` and `python3 tests/store.py`; dependencies have not been installed. The bounded prototype passed independent cross-provider source review within its recorded scope; subsequent changes require proportionate verification.

## Success and protection
A launchable local pilot shows persisted selected-project state, distinguishes closing the popover from quit, recovers after wake, and reports stale or unavailable sources honestly. Test explicit enrollment, conflict handling, malformed and missing data. No global assistant integration, login change or installation is authorized at this stage. A private remote exists; the new revision remains under review.
