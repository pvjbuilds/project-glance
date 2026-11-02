review_mode: cross-provider — 2026-11-02, Praj

# Decisions and assumptions

## 2026-11-02: Explicit enrollment
Praj selected a standalone floating overview and explicit per-session enrollment/association. One current item, at most two, in the pilot; no discovery or history import. The view tracks the overall project checkpoint rather than session-level steps.

## 2026-11-02: Implementation proposal
Codex proposes a dependency-free native macOS viewer with a local shared updater. This design is pending independent review; it is not yet validated. The working name is a placeholder.

## Assumptions
| ID | Claim | Impact if false | Evidence/date | Status | Owner | Validation action |
|---|---|---|---|---|---|---|
| A1 | A nonactivating panel can provide usable selection without stealing focus. | Core interaction requires revision. | Proposed 2026-11-02 | Unverified | Writer | Build and test in a real desktop session. |
| A2 | File coordination and atomic replacement can provide safe cross-process version checks. | Concurrent updates could be lost. | Proposed 2026-11-02 | Unverified | Writer | Design review and concurrent process tests. |
| A3 | Wake and file watching refresh state reliably across changed records and missing directories. | Stale displays could mislead. | Proposed 2026-11-02 | Unverified | Writer | Exercise lifecycle and recovery; show freshness. |
