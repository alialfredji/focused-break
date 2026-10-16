# Development and releases

## Local build

macOS 14+, Metal, and Swift 5.9+ are required. Install Xcode Command Line Tools, then run `swift test` and `bash scripts/build.sh`. The app is created at `dist/Focused Break.app`. No external Swift packages are used.

The internal executable/package name is EventHorizon and the bundle identifier remains `dev.alialfredji.event-horizon` for upgrade compatibility. Product-facing names are Focused Break.

`EVENT_HORIZON_SIGNING_IDENTITY` or a local ignored `.signing-identity` file can select a local development identity. Never commit certificates or private keys. Without an identity, the build uses ad-hoc signing.

## Publish a release

1. Update `CFBundleShortVersionString` and `CFBundleVersion` in `Info.plist`.
2. Update `docs/RELEASE-NOTES.md` with that release's changes.
3. Commit and push main. Wait for Build and test to pass.
4. Tag the same commit, matching the plist version exactly, and push it:

```sh
git tag v0.7.1
git push origin v0.7.1
```

The Release workflow tests and builds on separate Apple Silicon and Intel runners. It creates ad-hoc-signed ZIPs, drag-to-Applications DMGs, and SHA-256 checksum files. The publication job runs only after both builds succeed. It publishes a GitHub Release using the tag and release-notes file, marks it latest, and uploads all assets. Asset names stay stable so README latest-download links keep working.

To package locally: `RELEASE_TAG=v0.7.1 bash scripts/package-release.sh`. Local packaging produces only the host architecture. Use a new version tag for a new release; do not overwrite published versions.

GitHub Actions uses its scoped `GITHUB_TOKEN`; no personal token or signing certificate is needed. The standard macOS runner labels are documented by [GitHub](https://docs.github.com/en/actions/reference/runners/github-hosted-runners).

## Distribution limits

The project has no Developer ID certificate or notarization credentials configured. Do not describe these builds as notarized. Adding notarization requires the owner's Apple Developer distribution setup; it is separate from development signing.

CI checks compilation and deterministic tests on both architectures. It does not prove real-device screen-capture permissions, multiple displays, Spaces behavior, or performance. Manually test those before making wider compatibility claims.

## Source map

- `Sources/HorizonCore`: deterministic timer, effect settings, geometry, animation dynamics.
- `Sources/HorizonMedia`: GIF/image decoding and limits.
- `Sources/EventHorizon`: SwiftUI controls, AppKit lifecycle, ScreenCaptureKit, Metal rendering.
- `Tests`: timer, rendering dynamics, geometry, and image/GIF regression tests.
- `assets`: logo and original animation.
- `scripts`: app/icon builds, GIF upscale, and release packaging.

## Documentation images

The README uses the bundled logo and actual reminder GIF. These are product assets, not screenshots of the user's desktop. Keep private desktop captures out of documentation and release bundles.
