# Shared Project Contract

## Read at entry and after a handoff

Read [Project](PROJECT.md), [Current state](CURRENT_STATE.md), and relevant entries in
[Decisions and assumptions](DECISIONS.md) before substantive work. Follow their links
on demand. Re-read changed context after a harness switch or compaction.
Follow any applicable machine-level instructions in your own environment as well.
This repository contract is self-contained; personal rules from another machine are
not required to contribute. If an applicable required instruction is unavailable,
report the gap and continue only independent work. Never claim an unread file was loaded.

## Review mode

The first line of DECISIONS.md (full tier) or of CONTEXT.md (lite tier) declares
`review_mode`, dated, decided by Praj:
- `cross-provider`: the other provider reviews the frozen revision.
- `solo:claude` or `solo:codex`: a fresh session of the selected harness reviews the
  frozen revision. Praj has accepted that same-provider review shares the builder's
  blind spots; record that limitation with every solo review.
"The designated reviewer" below means whichever the declared mode names. A solo
review is never labeled a passed cross-provider review, and an undeclared provider is
never left pending. Change the mode by superseding the line, dated.

## Establish reality

Confirm the actual checkout, branch/revision, working-tree changes, current task and
writer. Reconcile shared state with files and check results before acting on it.
Treat prior chat, native memory, model agreement and this documentation as claims to
verify, not evidence. Keep source facts, inferences, proposals and unknowns distinct.
Use current primary sources for changing external claims; record links and dates.
Never invent a test result, source, user decision or rationale.

## Validate before building on assumptions

Record consequential assumptions in DECISIONS.md with impact and a validation action.
Before a major architecture, dependency, integration or scope commitment, have the
designated reviewer inspect requirements and primary evidence independently.
Validate assumptions whose failure would invalidate substantial downstream work.
Pause only dependent work while a blocking claim or review remains unresolved.
Routine reversible edits need proportionate checks; they do not require two reviews.

## Build, review, resolve

One designated writer owns the working tree. The designated reviewer reviews a frozen
commit or identified artifact snapshot; it does not edit the writer's files. Roles
can switch at a recorded handoff. Stop writing while capturing a review snapshot.
For uncommitted work, list tracked and untracked artifacts and their hashes; ensure
the reviewer can see that exact content. Another checkout needs the commit or a
sanitized patch plus required new files, not just a branch name or chat summary.

At a material milestone or before release, the designated reviewer independently checks
acceptance criteria, changed artifacts and consequential assumptions. It reads primary
evidence and performs safe relevant checks before comparing builder conclusions.
A second session from the same provider is not cross-provider review; in solo mode
it is the designated reviewer and is recorded as such.
Return findings with severity, file/source evidence, impact and a falsifying test or
concrete correction; include review scope, checks run, skipped checks and limits.
Agreement alone cannot close a finding. The writer records disposition and evidence;
recheck affected findings after fixes on the new revision. Contradictions stay visible.
Use an experiment or primary source to resolve facts; ask Praj only for a required
product tradeoff, explicit risk acceptance, or a writer–reviewer disagreement that
evidence has not settled. For a disagreement, state both positions fairly and pause
the disputed choice until he decides. No forced consensus.
If the designated reviewer is unavailable, mark review pending or unavailable and
continue independent work. Do not claim the checkpoint passed or dependent work is
validated.

## Close the task and hand over

In the same task as a material architecture, workflow, dependency, configuration or
project-state change, update affected shared documents. Update CURRENT_STATE.md with
actual results, uncertainties, review status and next action. Preserve decision history.
Keep routers small and remove superseded factual copies.
The reviewer returns a report; the writer incorporates it into the shared record.
Record reviewer harness/model if known, time, exact reviewed revision and disposition
of each finding. Use pending, changes-requested, passed-within-scope, or unavailable,
qualified with the mode — e.g. `passed-within-scope (solo:claude, accepted limitation)`.
Record any Praj-accepted risk explicitly without calling it a passed review.
Before stopping, check the work and shared-context diff together. Report what changed,
what was verified and what remains unverified. Never claim cross-validation unless
both providers actually reviewed the recorded scope; a solo review is a solo review.
