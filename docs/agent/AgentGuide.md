# Glance agent guide

Glance is local and opt-in. Only enroll a specific project when the person asks (for example, “add this to Glance” or “send this to Glance”). Use one stable project ID per work, check the existing list first, and update the existing entry rather than making a duplicate. A new chat must be explicitly connected before it updates; simply resuming work does not connect it. Session association is a coordination guard, not authentication. Do not discover other projects, import history, or store secrets, raw prompts, or transcripts.

Find the updater beside this guide in the installed app: if this guide is at `.../Glance.app/Contents/Resources/AgentGuide.md`, the executable is `.../Glance.app/Contents/MacOS/glance-store`. Quote its absolute path. The default local store is `~/Library/Application Support/ProjectOverview/`. Use `--store DIRECTORY` before a command for isolated experiments; installation does not enroll anything.

## Prepare a checkpoint

Use a stable unique ID for this chat: use the actual runtime chat or thread ID if available without searching history. Otherwise generate a UUID once as a new Glance association ID, retain and reuse it for this chat, and do not present it as the native chat ID. Do not inspect chat history to obtain an ID. IDs use only letters, numbers, hyphens and underscores, up to 80 characters. A new enrollment uses a unique request ID. Retry an uncertain enrollment using the same project and request IDs.

Create a temporary UTF-8 JSON file with an evidence-backed project goal, current checkpoint and status. Include the next unlocking action and a nested checklist only when supported by evidence. Checklist IDs must be unique across the tree; `done` must be a JSON boolean. Up to four levels and 200 entries are allowed; a completed item cannot have pending descendants. `currentMilestoneID` must name an existing pending item. Never infer completed work.

```json
{
  "name": "Example project",
  "goal": "Deliver the agreed outcome",
  "checkpoint": "The initial version is ready for review",
  "status": "Review in progress",
  "next": "Resolve review findings",
  "checklist": [{"id":"review","title":"Complete review","done":false,"children":[{"id":"verify","title":"Verify behavior","done":false}]}],
  "currentMilestoneID": "verify",
  "tokenUsage": {"estimate": 12000, "scope": "linked-chat", "source": "Example usage metadata", "coverage": "Example chat only; project total not measured", "asOf": "2026-01-01"}
}
```

The usage numbers above are illustrative, not real measurements. Omit `tokenUsage` unless supported by real evidence. It requires a nonnegative whole-number `estimate`, nonempty `source` and `coverage`; optional `scope` on the status is `project` or `linked-chat`, and optional `asOf` is a nonempty string. A task's optional usage has scope `task`. Do not split or allocate shared usage among tasks without evidence. Usage volume is not monetary cost. Optional string fields include `milestones`, `effort`, `sources` and `contextURL`; review content before saving.

## Read, enroll, connect, update, read back

Set `GLANCE_APP` to the actual absolute app path; do not assume a repository path. The following examples use placeholders; replace them with authorized values. `list` fails if no store exists; this does not authorize creation. Only explicit `enroll` creates one.

```sh
GLANCE_APP="$HOME/Applications/Glance.app"
GLANCE_STORE="$GLANCE_APP/Contents/MacOS/glance-store"
"$GLANCE_STORE" list
"$GLANCE_STORE" enroll PROJECT_ID REQUEST_ID SESSION_ID /absolute/path/status.json
"$GLANCE_STORE" connect PROJECT_ID SESSION_ID
"$GLANCE_STORE" list
"$GLANCE_STORE" update PROJECT_ID SESSION_ID EXPECTED_VERSION /absolute/path/status.json
"$GLANCE_STORE" list
```

Choose either enrollment for a new explicitly requested project or connection for an existing project; do not blindly run every example. Read the current version after connect, then provide that exact version for update. A conflict means read again and reconcile before retrying; never blindly overwrite. After any write error, the outcome may be uncertain: list and read back before deciding whether to retry. Read back and confirm the ID, content, association and actual version. The updater rejects corrupt current data rather than silently writing from a backup. A viewer backup is a previous snapshot, not proof of the latest state; preserve the corrupt file and seek an explicit recovery decision.
