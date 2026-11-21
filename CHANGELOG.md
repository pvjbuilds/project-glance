# Changelog

## 0.3.0 · 2026-11-21 · source prerelease

- Dismiss the popover when you click outside it, then reopen it from the menu bar.
- Open Help from a labeled button and copy the setup prompt with immediate feedback. The same action appears before the first project is added.
- See when the checkpoint was saved, expand a long next action, and find the milestone count above the checklist.

## 0.2.3 · local build

- Tested outside-click dismissal locally before incorporating it into 0.3.0.

## 0.2.2 — source alpha

- Read and validate the atomic primary snapshot without creating or writing a lock; writes remain serialized.
- Report lock access failures and post-replacement uncertainty more precisely.

## 0.2.1 — source alpha

- Native menu-bar status board for explicitly enrolled projects, with checkpoints, milestones, health and optional sourced details.
- Local version-checked updater with explicit session association and opt-in schema migration and recovery.
- Source build, local installation, agent guide and optional skill routers.

This is an early source release. The app is ad-hoc signed, not notarized. Login item, physical sleep/wake, Spaces and display changes remain unverified; power-loss behavior has not been tested. See the README for requirements and recovery caveats.
