#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
build_dir="build"
app="$build_dir/唱片机.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
xcrun swiftc -O -target arm64-apple-macos13.0 Player.swift main.swift -o "$build_dir/jukebox-arm64"
xcrun swiftc -O -target x86_64-apple-macos13.0 Player.swift main.swift -o "$build_dir/jukebox-x86_64"
lipo -create "$build_dir/jukebox-arm64" "$build_dir/jukebox-x86_64" -output "$app/Contents/MacOS/Jukebox"
cp Info.plist "$app/Contents/Info.plist"
ditto Resources "$app/Contents/Resources"
codesign --force --sign - "$app"
echo "构建完成：$app"
