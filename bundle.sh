#!/bin/sh
set -e
cd "$(dirname "$0")"
swift build -c release
APP=dist/NotificationBar.app
[ -d dist ] && rm -r dist
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/NotificationBar "$APP/Contents/MacOS/NotificationBar"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
cat > "$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleIdentifier</key><string>com.jbrann.notificationbar</string>
  <key>CFBundleName</key><string>NotificationBar</string>
  <key>CFBundleExecutable</key><string>NotificationBar</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
</dict></plist>
EOF
codesign --force --sign - "$APP"
echo "Built $APP"
