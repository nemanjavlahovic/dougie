#!/bin/bash
set -euo pipefail

project_dir="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_dir"

version="${1:-1.0.0}"
if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    printf 'Usage: %s [major.minor.patch]\n' "$0" >&2
    exit 2
fi
if [[ -n "${DOUGIE_NOTARY_PROFILE:-}" && -z "${DOUGIE_CODESIGN_IDENTITY:-}" ]]; then
    printf 'DOUGIE_NOTARY_PROFILE requires a Developer ID Application signing identity.\n' >&2
    exit 2
fi

output_dir="${DOUGIE_OUTPUT_DIR:-$project_dir/build}"
dist_dir="${DOUGIE_DIST_DIR:-$project_dir/dist}"
export DOUGIE_VERSION="$version"
"$project_dir/scripts/build.sh"
app="$output_dir/Dougie.app"
archs="$(lipo -archs "$app/Contents/MacOS/Dougie" | tr ' ' '-')"
suffix=""
if [[ -z "${DOUGIE_NOTARY_PROFILE:-}" ]]; then
    suffix="-local"
fi
base="Dougie-$version-macos-$archs$suffix"
mkdir -p "$dist_dir"
zip="$dist_dir/$base.zip"
dmg="$dist_dir/$base.dmg"
rm -f "$zip" "$dmg" "$dist_dir/$base.sha256"

if [[ -n "${DOUGIE_NOTARY_PROFILE:-}" ]]; then
    notary_zip="$dist_dir/$base-notary.zip"
    ditto -c -k --sequesterRsrc --keepParent "$app" "$notary_zip"
    xcrun notarytool submit "$notary_zip" --keychain-profile "$DOUGIE_NOTARY_PROFILE" --wait
    rm "$notary_zip"
    xcrun stapler staple "$app"
    xcrun stapler validate "$app"
    spctl --assess --type execute --verbose "$app"
fi

ditto -c -k --sequesterRsrc --keepParent "$app" "$zip"
stage="$(mktemp -d "${TMPDIR:-/tmp}/dougie-dmg.XXXXXX")"
trap 'rm -rf "$stage"' EXIT
ditto "$app" "$stage/Dougie.app"
ln -s /Applications "$stage/Applications"
hdiutil create -volname "Dougie" -srcfolder "$stage" -format UDZO -ov "$dmg" >/dev/null
if [[ -n "${DOUGIE_NOTARY_PROFILE:-}" ]]; then
    xcrun notarytool submit "$dmg" --keychain-profile "$DOUGIE_NOTARY_PROFILE" --wait
    xcrun stapler staple "$dmg"
    xcrun stapler validate "$dmg"
fi
hdiutil verify "$dmg" >/dev/null
(
    cd "$dist_dir"
    shasum -a 256 "$(basename "$zip")" "$(basename "$dmg")" > "$base.sha256"
)
printf 'Created %s, %s, and %s\n' "$zip" "$dmg" "$dist_dir/$base.sha256"
if [[ -z "${DOUGIE_NOTARY_PROFILE:-}" ]]; then
    printf 'Local artifacts are ad hoc signed and not notarized; do not publish them as a macOS release.\n'
fi
