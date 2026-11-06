#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
app=build/ProjectOverview.app
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources" build/module-cache
swiftc -module-cache-path build/module-cache Sources/Store.swift -o build/glance-store
cp build/glance-store "$app/Contents/MacOS/glance-store"
swiftc -module-cache-path build/module-cache Sources/Viewer.swift -o "$app/Contents/MacOS/ProjectOverview"
cp docs/agent/AgentGuide.md "$app/Contents/Resources/AgentGuide.md"
printf '%s\n' 'Glance local build' > "$app/Contents/Resources/GlanceInstallMarker"
version=$(cat VERSION)
cat > "$app/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict><key>CFBundleExecutable</key><string>ProjectOverview</string><key>CFBundleIdentifier</key><string>local.projectoverview.viewer</string><key>CFBundleName</key><string>Glance</string><key>CFBundleDisplayName</key><string>Glance</string><key>CFBundleShortVersionString</key><string>$version</string><key>CFBundleVersion</key><string>3</string><key>CFBundlePackageType</key><string>APPL</string><key>LSUIElement</key><true/><key>NSHighResolutionCapable</key><true/></dict></plist>
PLIST
# Local ad-hoc signature stabilizes this build's identity; it is not notarization.
codesign --force --deep --sign - "$app"
codesign --verify --deep --strict "$app"
