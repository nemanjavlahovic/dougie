# Release process

## Before publishing

1. Confirm the repository contains only assets with redistribution rights. The public source omits the former TV footage cameo and demo. Do not make an older repository history containing those assets public.
2. Review the version in `Resources/Info.plist`, update the changelog in the GitHub release notes, and run `swift test --disable-sandbox`.
3. Use a **Developer ID Application** certificate for the release identity. An Apple Development or Apple Distribution certificate is not a substitute for direct macOS distribution.
4. Store App Store Connect notarization credentials with `xcrun notarytool store-credentials PROFILE` in the release Mac's keychain. Keep credentials out of Git.

## Build, sign, notarize, and package

```sh
export DOUGIE_CODESIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)"
export DOUGIE_NOTARY_PROFILE="your-notary-profile"
./scripts/package-release.sh 1.0.0
```

The script builds a release app with hardened runtime, submits it for notarization, staples its ticket, then creates and notarizes the `.dmg`. It also creates a `.zip` containing the stapled app and a SHA-256 checksum file. Artifact names include the detected CPU architecture. Run this on each supported architecture, or build and verify a universal app before claiming universal support.

Inspect the outputs before upload:

```sh
codesign --verify --deep --strict --verbose=2 build/Dougie.app
spctl --assess --type execute --verbose build/Dougie.app
xcrun stapler validate build/Dougie.app
hdiutil verify dist/Dougie-1.0.0-macos-*.dmg
(cd dist && shasum -a 256 -c Dougie-1.0.0-macos-*.sha256)
```

Mount the `.dmg` on a clean Mac, drag the app to Applications, launch it, and check the timer, display sleep option, and login item. The release must work without Xcode installed.

## GitHub release

1. Publish the source only from a repository whose history does not contain the removed footage. Set the repository visibility to public after checking the license, README, and CI results.
2. Tag the tested commit as `v1.0.0`.
3. Create a GitHub release from that tag with a concise changelog, supported macOS version and CPU architecture, and the notarized `.dmg`, `.zip`, and `.sha256` files. Do not upload artifacts with `-local` in their name.
4. Download the release files from GitHub and verify the checksum again.

Local packaging without signing credentials is useful for smoke tests only. A local `.dmg` or `.zip` is not a public release artifact.
