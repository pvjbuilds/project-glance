# TDD evidence — remaining improvements

Approved seams: updater CLI/readback, visible UI actions/results, installed-app launch/reopen and saved-state reload. Tests use disposable stores. Each entry records observed RED before implementation, then GREEN. The recovery design passed preflight within scope (`solo:codex`, same-provider blind spots); full implementation review remains pending.

- Checkpoint invalid completion: `python3 tests/improvements.py` failed `Incomplete checkpoint closure was accepted`; after validation and rebuild the command passed.
- Reversed effort range: same command failed `Reversed effort range was accepted`; after validation and rebuild passed.
- Recurring without source: same command failed `Recurring cycle without source was accepted`; after validation and rebuild passed.
- Generation migration: same command failed `Explicit migration to generation-aware revisions failed: ... Invalid project ID`; after migration/list support and rebuild passed.
- Recovery corrupt primary: same command failed `Explicit recovery failed` with JSON parse error; after explicit recovery and rebuild passed, including old token and numeric rejection and fresh token success.
- Recovery missing primary: same command failed `Missing primary recovery failed: ... Store does not exist`; after recovery-specific entry handling and rebuild passed.
- Checkpoint details UI: coordinator ran `python3 tests/native_ui_test.py` in a working desktop; RED exit 1, `Precondition failed: checkpoint closure details missing` (SIGTRAP 5). After adding condition and completion evidence to Details, GREEN exit 0 with `Native checks passed` marker.
- Effort range UI: coordinator ran native harness, RED exit 1 `effort range details missing` (SIGTRAP 5); after Details displayed explicit range and source, GREEN exit 0 with success marker.
- Recurring cycle UI: coordinator ran native harness, RED exit 1 `recurring cycle details missing` (SIGTRAP 5); after Details displayed supplied last/current/next, GREEN exit 0 with success marker.
- Token Details UI: coordinator native harness RED exit 1 `usage displayed outside Details` (SIGTRAP 5); after moving scoped usage to Details, GREEN exit 0 with success marker.
- All-projects UI: coordinator native harness RED exit 1 `all projects action missing` (SIGTRAP 5); after adding the list and project selection, GREEN exit 0 with success marker.
- Malformed-state UI: coordinator native harness RED exit 1 `invalid record was displayed as available`; viewer validation added for generation and optional structures; GREEN exit 0 with success marker.
- External wait validation: updater RED `External wait without source was accepted`; after requiring a sourced reason and rebuilding, GREEN passed.
- External wait UI: coordinator native harness RED exit 1 `external wait details missing` (SIGTRAP 5); after displaying sourced wait separately from effort, GREEN exit 0 with success marker.

Final local checks: `scripts/build.sh`, `python3 tests/improvements.py`, `python3 tests/store.py`, `python3 tests/interrupted_writes.py`, `python3 tests/interrupted_recovery.py`, `python3 tests/release_reliability.py`, and `python3 tests/show_launcher.py` passed. Twelve interrupted ordinary writes passed across four stages; four interrupted recoveries passed across before/after archive, before primary and immediately after primary rename before directory sync. These are isolated SIGKILL tests, not power-loss simulation. Schema-2 connect preserves generation and current status, invalidates the old token by incrementing revision, and a fresh token succeeds. Actual sleep/wake, login, Spaces and display changes remain untested.

Independent final review passed within scope (`solo:codex`, same-provider blind spots). Reviewer independently compiled current Store, typechecked Viewer, ran store and improvements suites and four interrupted recovery boundaries, and confirmed the baseline updater rejects schema-2 list/connect/enroll/update. Coordinator inspected all-projects and mid-scroll Details fixtures. Final Viewer SHA-256 `fb3e6a82d5e1f51c3fcb1e5ee5522ba9816d0455c2a0a3e53f5a6ea14eb088c2`; the last delta only corrects preview capture and adds fixture positions.
