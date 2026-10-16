# Development and releases

## Prerequisites

- A Mac running macOS 14 or later with Metal support.
- Xcode Command Line Tools with Swift 5.9 or later. Full Xcode is optional.
- Git (included with the Command Line Tools).

If the Command Line Tools are not installed, run this and finish the macOS installer before continuing:

```sh
xcode-select --install
```

Check your tools:

```sh
swift --version
git --version
```

You do not need Node.js, Homebrew, an Apple Developer account, API keys, or a `.env` file. The app uses Apple's frameworks and has no external Swift package dependencies.

## Clone, test, and run

```sh
git clone https://github.com/alialfredji/focused-break.git
cd focused-break
swift test
bash scripts/build.sh
open "dist/Focused Break.app"
```

The build script creates the app, copies its resources, builds the icon, and signs it locally. It builds for your Mac's architecture. The first build can take longer while Swift prepares its build cache.

To contribute without repository write access, fork the repository on GitHub and clone your fork instead. Then create a branch:

```sh
git switch -c improve-break-controls
```

## Make a change

Edit the Swift files in your preferred editor. If you use Xcode, open `Package.swift`. See the source map below to find the relevant code.

After editing:

1. Quit the running Focused Break app from its menu or with Command-Q. Closing its window does not quit it.
2. Test and rebuild:

   ```sh
   swift test
   bash scripts/build.sh
   open "dist/Focused Break.app"
   ```

3. Check the behavior you changed in the rebuilt app. For appearance changes, use **Preview** and the **10-second desktop test**. For timer changes, try a short focus session and verify the break and return to the app.

There is no hot reload. Rebuilding does not replace an already running process. The `Run Focused Break.command` launcher builds only when the app is missing; use the build command above after source changes.

For a separate app identity while trying changes, quit any running preview build and run:

```sh
bash scripts/build.sh --preview
open "dist/gravity-preview/Focused Break Preview.app"
```

The preview has its own preferences, saved-image storage, and screen-access permission, separate from the regular app.

## Open a pull request

Keep the change focused. Run the tests, check the affected behavior, then commit and push your branch to your fork:

```sh
git add <changed-files>
git commit -m "Describe the change"
git push -u origin improve-break-controls
```

Open a pull request against this repository's `main` branch. The PR template asks what changed, why, and how you checked it. Include a screenshot for visual changes, with private content hidden. Do not commit `dist/`, `.build/`, signing settings, or credentials.

## Local signing and permissions

The internal executable/package name is EventHorizon and the bundle identifier remains `dev.alialfredji.event-horizon` for upgrade compatibility. Product-facing names are Focused Break.

`EVENT_HORIZON_SIGNING_IDENTITY` or a local ignored `.signing-identity` file can select a local development identity. Never commit certificates or private keys. Without an identity, the build uses ad-hoc signing.

Screen access is optional: use the basic reminder, Grid, or Space without it. Live desktop preview and distortion require macOS screen-recording permission. Ad-hoc-signed rebuilds may require you to re-enable permission for the rebuilt app. See [installation and permissions](INSTALL.md).

## Common setup problems

| Problem | What to check |
| --- | --- |
| `swift` or `git` is missing | Finish installing Command Line Tools, then reopen Terminal. |
| Build reports an unsupported Swift version | Check `swift --version` and update your Xcode or Command Line Tools. |
| The app looks unchanged | Quit it completely, rebuild, and open the app from this checkout's `dist` folder. |
| Live desktop preview is unavailable | Check screen-recording permission for the exact app build, or use Grid/Space while developing. |
| Need a clean build | Quit the app, run `swift package clean`, then rebuild. This leaves saved preferences and images intact. |

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
