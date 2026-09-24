#!/bin/bash
set -euo pipefail

project_dir="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_dir"
scratch_dir="${DOUGIE_BUILD_DIR:-$project_dir/.build}"
output_dir="${DOUGIE_OUTPUT_DIR:-$project_dir/build}"
export CLANG_MODULE_CACHE_PATH="$scratch_dir/ModuleCache"
export SWIFTPM_MODULECACHE_OVERRIDE="$scratch_dir/ModuleCache"

swift build -c release --disable-sandbox --scratch-path "$scratch_dir"
binary_dir="$(swift build -c release --show-bin-path --disable-sandbox --scratch-path "$scratch_dir")"
app_dir="$output_dir/Dougie.app"
rm -rf "$app_dir"
mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"
cp "$binary_dir/Dougie" "$app_dir/Contents/MacOS/Dougie"
cp Resources/Info.plist "$app_dir/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${DOUGIE_VERSION:-1.0.0}" "$app_dir/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${DOUGIE_BUILD_NUMBER:-1}" "$app_dir/Contents/Info.plist"
cp Sources/Dougie/Assets/lludix-cup.png "$app_dir/Contents/Resources/lludix-cup.png"
swift scripts/make-icon.swift "$output_dir"
cp "$output_dir/AppIcon.icns" "$app_dir/Contents/Resources/AppIcon.icns"
if [[ -n "${DOUGIE_CODESIGN_IDENTITY:-}" ]]; then
    codesign --force --options runtime --timestamp --sign "$DOUGIE_CODESIGN_IDENTITY" "$app_dir"
else
    codesign --force --sign - "$app_dir"
fi
codesign --verify --strict "$app_dir"
printf 'Built %s\n' "$app_dir"
