review_mode: solo:codex — 2026-11-05, Praj (local review chosen; same-provider blind spots)

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

## 2026-11-05: Menu-bar presentation
Praj selected a dark rounded menu-bar popover using a screenshot reference, superseding the floating card as the primary interface. Saved milestones are displayed as a read-only checklist; status is never inferred from prose. Product name remains provisional. The independent local Codex source review passed within its recorded scope; it shares provider blind spots.

## 2026-11-05: Review mode
Praj chose to keep this review local, superseding `cross-provider` selected on 2026-11-02. The designated reviewer is a fresh Codex session; same-provider review shares the builder’s blind spots and is not cross-provider review. The historical 2 November cross-provider review remains recorded.

## 2026-11-06: Nested milestones and scoped usage
Praj requested a compact overview, explicit nested milestone disclosure and token estimates where evidence exists. Completion and the current branch are explicitly saved; usage is scoped and sourced rather than inferred or apportioned. The menu-bar item becomes a monochrome system symbol. Local review remains the selected review mode.
