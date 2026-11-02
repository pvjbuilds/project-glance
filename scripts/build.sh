#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
mkdir -p build/ProjectOverview.app/Contents/MacOS build/module-cache
swiftc -module-cache-path build/module-cache Sources/Store.swift -o build/glance-store
swiftc -module-cache-path build/module-cache Sources/Viewer.swift -o build/ProjectOverview.app/Contents/MacOS/ProjectOverview
cat > build/ProjectOverview.app/Contents/Info.plist <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict><key>CFBundleExecutable</key><string>ProjectOverview</string><key>CFBundleIdentifier</key><string>local.projectoverview.viewer</string><key>CFBundleName</key><string>Project Overview</string><key>CFBundlePackageType</key><string>APPL</string><key>LSUIElement</key><true/><key>NSHighResolutionCapable</key><true/></dict></plist>
PLIST
