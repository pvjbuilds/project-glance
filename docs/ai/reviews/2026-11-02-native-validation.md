# Native validation — 2026-11-02

The parent Codex session performed these checks on the local macOS desktop. The initial app launch used the default store; the only real enrolled record was Project Glance. A separate QA app with a separate bundle identifier and temporary store contained fictional fixtures only.

- The real card displayed the four priority fields; the selector opened and the live viewer refreshed after enrollment and update. The floating panel remained visible with an inactive title bar when Finder was raised on an ordinary desktop. Command-Q terminated its own process.
- The isolated demo showed two projects with the same name as distinct selections; selecting the second showed its own checkpoint. Scrolling reached both the end of a long source field and the Updated footer.
- Closing the QA window left its process running. Reopening the QA app restored the selected second demo and checkpoint. Its displayed update age advanced from 14 to 16 to 19 minutes without agent updates. QA was then quit; the real app was relaunched and showed only Project Glance.
- The parent reviewed the later file-context safety change in source: file URLs are revealed in Finder. This was not part of Claude's earlier reviewed Viewer hash, and the reveal action was not reported as desktop-tested.

These observations do not establish full-screen or Spaces behavior, actual sleep/wake recovery, multi-display behavior, login-item operation, or general accessibility. No login item or global agent integration was enabled. The cross-provider source review and its exact reviewed hashes are recorded separately in [Claude review](2026-11-02-claude.md).
