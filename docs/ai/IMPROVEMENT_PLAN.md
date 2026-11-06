# Glance improvement plan — 2026-11-06

Scope: preserve explicit enrollment and association, one canonical local record per project, no discovery, history import, model polling, cloud service, or new global hooks. Fields are optional and backward-compatible. A fresh Codex reviewer checks each frozen material batch under `solo:codex`; this shares provider blind spots.

- [ ] **1. Real Mac reliability checks.** Acceptance: document reproducible launch, popover, reload and recovery checks with actual results and environment; distinguish automated harness evidence from physical behavior. Dependencies: installed candidate and batch review. Human-only gates: sleep/wake, login, Spaces/full-screen and display changes require Praj to perform or explicitly direct; do not change them autonomously.
- [x] **2. Explicit project health.** Acceptance: optional saved state Moving, Waiting on you, Blocked, Parked, Needs scoping or Checkpoint complete, with a clear reason; older records remain valid and do not get inferred health. Dependencies: validated store schema and display.
- [x] **3. Freshness and updater ownership.** Acceptance: show last saved time and updater when evidenced; distinguish explicitly recorded waiting/parked from age-based stale information, without inferring activity or ownership. Dependencies: 2 and saved metadata.
- [x] **4. Dependable associated-chat updates.** Acceptance: explicit session association gates changes; successful update reports saved project and revision; stale or failed writes have actionable messages and do not claim success. Dependencies: existing serialized version checks; test CLI behavior.
- [x] **5. Compact all-projects view.** Acceptance: show all explicitly enrolled projects in a compact scannable view, preserve project selection and truthful empty/error states. Dependencies: 2–3 and native layout review.
- [x] **6. Checkpoint closure.** Acceptance: record a finish condition and explicit completion evidence; closing a checkpoint does not imply the overall project is complete. Dependencies: 2 and explicit status model.
- [x] **7. Evidence-backed effort ranges.** Acceptance: show optional sourced effort ranges separately from elapsed or external waiting time; never invent precision. Dependencies: schema and update guidance.
- [x] **8. Safe recovery and errors.** Acceptance: errors distinguish unavailable, invalid and uncertain write outcomes; any restore design prevents version reuse/ABA and is tested under interruption. Dependencies: independent design review before implementing restore.
- [x] **9. Token reporting in Details.** Acceptance: show only explicitly supplied scoped and sourced token data in Details; absence remains unknown. Dependencies: existing scoped usage model and compact layout.
- [x] **10. Opt-in recurring work.** Acceptance: explicitly enrolled recurring work shows last, next and current cycle with clear source and no invented schedule; ordinary projects need no recurring fields. Dependencies: closure and freshness semantics.

Items 2–4 completed in 0.1.1 (2); items 5–10 implemented and reviewed in candidate 0.2.0 (3), with installation and live readback pending. See [current state](CURRENT_STATE.md). Item 1 remains open for actual physical checks.

## Batches and gates

1. First: items 2–4 and safe automated checks for 1. Freeze, run meaningful checks, and obtain independent review before installation. Physical checks stay pending until performed.
2. Next: items 5–7 and 9, shaped by observed layout and available evidence. Review each material batch.
3. Last: item 8 after recovery design review, and item 10 after its cycle semantics are defined. No item is complete solely because it was planned or rendered in a fixture.
