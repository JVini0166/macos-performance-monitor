#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
swift build -c release
APP="dist/Performance Monitor.app"
ICONSET=".build/AppIcon.iconset"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$ICONSET"
cp .build/release/PerformanceMonitor "$APP/Contents/MacOS/PerformanceMonitor"
RESOURCE_BUNDLE="$(swift build -c release --show-bin-path)/PerformanceMonitor_PerformanceMonitor.bundle"
# ditto updates the resource bundle without nesting it on repeated builds.
ditto "$RESOURCE_BUNDLE" "$APP/Contents/Resources/PerformanceMonitor_PerformanceMonitor.bundle"
for size in 16 32 128 256 512; do
    sips -z "$size" "$size" assets/app-icon.png --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
    retina=$((size * 2))
    sips -z "$retina" "$retina" assets/app-icon.png --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>PerformanceMonitor</string>
<key>CFBundleIdentifier</key><string>dev.josevinicius.performance-monitor</string>
<key>CFBundleDevelopmentRegion</key><string>en</string>
<key>CFBundleLocalizations</key><array><string>en</string><string>pt-BR</string></array>
<key>CFBundleName</key><string>Performance Monitor</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>1.0</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
codesign --force --sign - "$APP"
echo "App criado em: $APP"
