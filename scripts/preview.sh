#!/bin/bash
set -euo pipefail

project_dir="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_dir"
scratch_dir="${DOUGIE_BUILD_DIR:-$project_dir/.build}"
preview_dir="${1:-${TMPDIR:-/tmp}/Dougie-previews}"
export CLANG_MODULE_CACHE_PATH="$scratch_dir/ModuleCache"
export SWIFTPM_MODULECACHE_OVERRIDE="$scratch_dir/ModuleCache"
swift build --disable-sandbox --scratch-path "$scratch_dir"
binary_dir="$(swift build --show-bin-path --disable-sandbox --scratch-path "$scratch_dir")"
swiftc -Xfrontend -disable-sandbox -parse-as-library -I "$binary_dir/Modules" \
    Sources/Dougie/AwakePanel.swift Sources/Dougie/LoginSettings.swift Sources/Dougie/CoffeeCup.swift Sources/Dougie/CoffeeStir.swift \
    "$binary_dir/Dougie.build/DerivedSources/resource_bundle_accessor.swift" \
    scripts/render-panel.swift "$binary_dir"/DougieCore.build/*.swift.o -o "$scratch_dir/render-panel"
"$scratch_dir/render-panel" "$preview_dir" "${@:2}"
