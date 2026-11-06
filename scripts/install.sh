#!/bin/sh
set -eu
project_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
source_app="$project_root/build/ProjectOverview.app"
install_dir=${GLANCE_INSTALL_DIR:-"$HOME/Applications"}
target="$install_dir/Glance.app"
plist=/usr/libexec/PlistBuddy
identity() { "$plist" -c 'Print :CFBundleIdentifier' "$1/Contents/Info.plist" 2>/dev/null; }
owned() { [ -f "$1/Contents/Resources/GlanceInstallMarker" ] && [ "$(cat "$1/Contents/Resources/GlanceInstallMarker")" = 'Glance local build' ] && [ "$(identity "$1")" = 'local.projectoverview.viewer' ]; }
if [ ! -d "$source_app" ] || ! owned "$source_app"; then printf '%s\n' 'Build the Glance app first using scripts/build.sh.' >&2; exit 1; fi
mkdir -p "$install_dir"
if [ -L "$target" ]; then printf '%s\n' 'An unexpected Glance.app link exists; it was not changed.' >&2; exit 1; fi
if [ -e "$target" ] && ! owned "$target"; then printf '%s\n' 'An unrecognized Glance.app already exists; it was not changed.' >&2; exit 1; fi
stage=$(mktemp -d "$install_dir/.glance-install.XXXXXX")
backup="$stage/previous.app"
rollback() {
    if [ -d "$backup" ] && [ ! -e "$target" ]; then mv "$backup" "$target" || printf '%s\n' "Restore needed: $backup" >&2; fi
    if [ ! -d "$backup" ]; then rm -rf "$stage"; fi
}
trap rollback EXIT HUP INT TERM
ditto "$source_app" "$stage/new.app"
owned "$stage/new.app" || { printf '%s\n' 'Copied app failed identity check.' >&2; exit 1; }
if [ -e "$target" ]; then mv "$target" "$backup"; fi
mv "$stage/new.app" "$target"
if [ -d "$backup" ]; then rm -rf "$backup"; fi
printf 'Installed Glance at %s\n' "$target"
