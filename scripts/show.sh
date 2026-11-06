#!/bin/sh
set -eu
project_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
built="$project_root/build/ProjectOverview.app"
installed="${GLANCE_INSTALL_DIR:-$HOME/Applications}/Glance.app"
if [ -L "$installed" ]; then printf '%s\n' 'The installed Glance.app is an unexpected link; it was not opened.' >&2; exit 1; fi
if [ -e "$installed" ]; then
    id=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$installed/Contents/Info.plist" 2>/dev/null || true)
    if [ "$id" != 'local.projectoverview.viewer' ] || [ ! -f "$installed/Contents/Resources/GlanceInstallMarker" ] || [ "$(cat "$installed/Contents/Resources/GlanceInstallMarker")" != 'Glance local build' ]; then printf '%s\n' 'The installed Glance.app is not recognized; it was not opened.' >&2; exit 1; fi
    if [ -d "$built" ] && { ! cmp -s "$built/Contents/Info.plist" "$installed/Contents/Info.plist" || ! cmp -s "$built/Contents/MacOS/ProjectOverview" "$installed/Contents/MacOS/ProjectOverview" || ! cmp -s "$built/Contents/MacOS/glance-store" "$installed/Contents/MacOS/glance-store" || ! cmp -s "$built/Contents/Resources/AgentGuide.md" "$installed/Contents/Resources/AgentGuide.md"; }; then printf '%s\n' 'The installed Glance app is older than this build. Run scripts/install.sh first.' >&2; exit 1; fi
    open "$installed" --args --show
else
    if [ ! -d "$built" ]; then printf '%s\n' 'Glance is not installed or built. Run scripts/build.sh first.' >&2; exit 1; fi
    open "$built" --args --show
fi
