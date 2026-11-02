# Project Glance (working name)

A local prototype of a macOS menu-bar project overview. Enrollment and session association are explicit; no project discovery, cloud service, or model process is included. The name is provisional. This is a prototype under review, not a public release.

## Build and check

Requires macOS, Apple Command Line Tools and Swift. From the project root:

```sh
scripts/build.sh
python3 tests/store.py
open build/ProjectOverview.app
```

The app uses `~/Library/Application Support/ProjectOverview/store.json`. The CLI and viewer use that same default. Pass `--store DIRECTORY` before the command to the CLI, or after the app executable to the viewer, to use a different store for experiments. Only explicit enrollment creates a store; a missing store makes list, connect and update fail without creating it. No data is enrolled by installing or launching the app. The source and build contain no example personal project data.

The store interface is experimental and may change. Both assistants must explicitly associate each new session before updating; no automatic chat integration has been installed. Commands and payload format will be documented after review. Do not put secrets or transcripts into status fields.

Shared project contract, architecture, review and limitations: [docs/ai/README.md](docs/ai/README.md).

## How can an agent add or update a project?

Give the agent this repository and say: “Read the shared project contract and README, then prepare an explicit enrollment using a temporary store first. Ask before using my real project details. Never scan my projects or import history.” The agent must be explicitly asked to enroll a specific project; a later session must be explicitly connected. Choose a stable unique session ID for each conversation (for example, a harness name plus its thread ID when available); retain it for that session, and explicitly connect a new session before it updates. Do not scan conversation history to invent one. A project ID, request ID and session ID contain only letters, numbers, hyphens or underscores. Each status payload is a JSON object with nonempty `goal`, `checkpoint`, and `status` strings; optional string fields are `name`, `milestones`, `next`, `effort`, `sources`, and `contextURL`. Sources are displayed as selectable text. A contextURL with the file, http, https or codex scheme can be accessed only by choosing Open project context from the menu: file URLs are revealed in Finder, and supported web or Codex URLs open through macOS. Nothing is opened automatically or run as a shell command. Review all content before saving it.

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

The menu offers a macOS-managed Open at Login toggle. It is never enabled automatically; macOS may request approval. This behavior is unverified in the prototype. Show / Hide and Quit are separate menu actions.

## What happens when data is old or unavailable?

The card displays its last update time and marks entries older than seven days as stale. It retains the last valid view in memory if a later read fails, with an unavailable notice. This fallback does not persist across app restarts. Missing data never means a project is complete.

## What is the release status?

The project name is a placeholder. The app is a local prototype pending native interaction, reliability and independent cross-provider review. No license, public release or installation method has been selected.
