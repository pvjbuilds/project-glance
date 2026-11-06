# Read-only list and host permissions — 7 November 2026

Passed within scope, solo:codex; accepted same-provider blind spots. Terra6.1medium sole implementation writer; fresh Terra6.1medium reviewer; Sol orchestration and installed verification.

Root reproduced installed0.2.1 list failing Cannot open lock while primary JSON was readable under workspace-write. New chmod-based publicCLI fixture reproduced RED, then passed GREEN. New list opens no writer lock and validates one atomically saved primary snapshot. Writers retain exclusive lock and version/generation CAS. Missing/corrupt primary never falls back to backup. Denied enroll/update preserve primary and backup; actionable lock error names store directory and required host grant. Uncertainty guidance appears after any successful file replacement, including backup advancement.

Reviewer independently compiled source and ran read_only_store.py and store.py; passed. Local regression suites passed, including12 interrupted-writer and4 recovery boundaries; not power-loss tests. Root candidate and installed0.2.2 listing succeeded in actual sandbox without escalation. Primary bytes and LocalVoicev2 digest unchanged.

Reviewed SHA256 Store36f820358607f5a7b0736995c159186445536c2578bf3ff9f3710a386c17a6c2; read-onlytest0ef97c89236bf319b05eb9c8b638545366b546b5819dbab211ebc7bd4655fc5c; CI87b115622ea82016fb459aab72f573f55a1ac31fd40defc741d0c53222d21f5d. Installed viewer/updater/guide match build; signature verified. Later coordinator evidence text lies outside the frozen source hashes.
