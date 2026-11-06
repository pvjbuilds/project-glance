# Project Glance (working name)

A local macOS menu-bar project overview (version 0.1.0). Enrollment and session association are explicit; no project discovery, cloud service, or model process is included. The name is provisional. Version 0.1.0 build 1 is installed locally and has passed the stated local review; it is not a public release.

## Build and check

Requires macOS, Apple Command Line Tools and Swift. From the project root:

```sh
scripts/build.sh
python3 tests/store.py
scripts/show.sh
```

To install the built app locally, run `scripts/install.sh`; it installs to `~/Applications/Glance.app` and refuses an unrecognized existing app. `scripts/install-agent-skills.sh --codex-only` prepares a derived Codex router; the default targets both Codex and Claude and requires appropriate authorization. The installer refuses unknown existing skills. Both routers are installed locally following explicit authorization. The earlier installation attempt was rejected by automatic approval review before execution; fresh-session discovery checks passed for both routers. A new chat may be needed before a newly installed skill is discovered. Installing does not enroll a project or invoke a model. The app’s `?` help includes a copyable agent prompt and the standalone guide is bundled at `Contents/Resources/AgentGuide.md`.

The app uses `~/Library/Application Support/ProjectOverview/store.json`. The CLI and viewer use that same default. Pass `--store DIRECTORY` before the command to the CLI, or after the app executable to the viewer, to use a different store for experiments. Only explicit enrollment creates a store; a missing store makes list, connect and update fail without creating it. No data is enrolled by installing or launching the app. The source and build contain no example personal project data.

The show script opens the existing popover or launches the app and opens it. Ordinary app launch without `--show` stays silent. Both assistants must explicitly associate each new session before updating. A separately installed skill routes explicit Glance requests to the bundled guide; it does not enroll automatically. Do not put secrets or transcripts into status fields.

Shared project contract, architecture, review and limitations: [docs/ai/README.md](docs/ai/README.md).

## How can an agent add or update a project?

Give the agent this repository and say: “Read the shared project contract and README, then prepare an explicit enrollment using a temporary store first. Ask before using my real project details. Never scan my projects or import history.” The agent must be explicitly asked to enroll a specific project; a later session must be explicitly connected. Choose a stable unique session ID for each conversation (for example, a harness name plus its thread ID when available); retain it for that session, and explicitly connect a new session before it updates. If no native ID is available, generate a UUID once as a Glance association ID and retain it for this chat; do not claim it is the native ID. Do not scan conversation history to obtain one. A project ID, request ID and session ID contain only letters, numbers, hyphens or underscores. Each status payload is a JSON object with nonempty `goal`, `checkpoint`, and `status` strings; optional string fields are `name`, `milestones`, `next`, `effort`, `sources`, and `contextURL`. An optional `checklist` is an array of objects such as `{"id":"review","title":"Complete review","done":false}`; IDs must be unique and `done` must be a JSON boolean. Entries are display-only and legacy records show no milestones rather than inferred completion. An item may have a `children` array of the same objects, with at most four levels and 200 items total; IDs are unique across the entire tree. Completed items cannot have pending descendants. Optional `currentMilestoneID` names an existing pending item; its path opens by default, while other branches stay closed until selected. Manual choices are remembered per project. Optional `tokenUsage` on the status or an item has `estimate` (nonnegative whole JSON number), `source` and `coverage` (nonempty strings), and optional `asOf` and `scope`. Status scope is `project` (default) or `linked-chat`; item scope is `task` (default). Estimates are not summed or attributed automatically; missing usage is not measured. Details exposes source and coverage. When a contextURL is supplied, the popover shows an Open project context button. File, http, https and codex URLs are supported: file URLs are revealed in Finder, and supported web or Codex URLs open through macOS. Nothing is opened automatically or run as a shell command. Review all content before saving it.

```sh
build/glance-store [--store DIRECTORY] list
build/glance-store [--store DIRECTORY] enroll PROJECT_ID REQUEST_ID SESSION_ID /path/to/status.json
build/glance-store [--store DIRECTORY] connect PROJECT_ID SESSION_ID
build/glance-store [--store DIRECTORY] update PROJECT_ID SESSION_ID EXPECTED_VERSION /path/to/status.json
```

Use a unique request ID for each new enrollment; retry the same ID with the same project ID after an unknown outcome. A list shows versions; reconnecting an existing session is idempotent. A stale version is rejected, so read and reconcile before retrying. The CLI's session IDs enforce the workflow between cooperating agents; they are not a security boundary against other local processes. Do not run multiple writers that bypass the CLI.

## Does it run a model or search my computer?

No. The viewer reads the one local store. It does not discover projects, start models, upload data, or import conversations. Updates happen only when an associated session runs the updater.

## Does it open at login?

The popover footer opens Settings, which offers a macOS-managed Open at Login control. It is never enabled automatically; macOS may request approval. This login-item behavior remains unverified. Click the menu-bar item to show or close the popover; use Quit in its footer to exit. It does not open a popover automatically at launch.

## What happens when data is old or unavailable?

The card displays its last update time and marks entries older than seven days as stale. It retains the last valid view in memory if a later read fails, with an unavailable notice. If the current store is unavailable after a restart, the viewer can show the previous validated backup with an unavailable notice. Writes fail while the primary is missing or invalid; there is no automatic restore. The backup and primary are separate synced replacements, not a single transaction. A write error after replacement can leave the outcome uncertain: read the current state before retrying. Real power-loss behavior is untested. Missing data never means a project is complete.

## What is the release status?

The project name is a placeholder. Version 0.1.0 build 1 is installed locally and passed a same-provider local source review. Further native lifecycle checks remain. Same-provider review shares blind spots. The local ad-hoc signature is not Developer ID signing or notarization. No public release or license has been selected. See [release evidence and footprint](docs/ai/reviews/2026-11-06-release-review.md).
