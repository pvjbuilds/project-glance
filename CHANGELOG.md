# Changelog

## 0.2.2 — source alpha

- Read and validate the atomic primary snapshot without creating or writing a lock; writes remain serialized.
- Report lock access failures and post-replacement uncertainty more precisely.

## 0.2.1 — source alpha

- Native menu-bar status board for explicitly enrolled projects, with checkpoints, milestones, health and optional sourced details.
- Local version-checked updater with explicit session association and opt-in schema migration and recovery.
- Source build, local installation, agent guide and optional skill routers.

This is an early source release. The app is ad-hoc signed, not notarized. Login item, physical sleep/wake, Spaces and display changes remain unverified; power-loss behavior has not been tested. See the README for requirements and recovery caveats.
