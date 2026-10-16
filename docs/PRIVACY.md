# Privacy and storage

Focused Break has no account, backend, analytics, or network service. It does not collect browsing, typing, or app-usage history.

## Screen permission

Optional desktop distortion and live preview use ScreenCaptureKit. Frames stay in memory as rendering textures; this app does not upload them or write a screen recording. Audio is not requested. The app excludes its own windows from capture.

Desktop-effect capture stops when a break/test ends, pauses, or is stopped. The preview has a separate stream: collapse Preview, select Grid or Space, or disable Distort desktop to stop it. Quitting stops all capture.

## Local data

- Preferences: UserDefaults domain `dev.alialfredji.event-horizon`.
- Saved custom image: `~/Library/Application Support/dev.alialfredji.event-horizon/reminder.asset`.
- Desktop-test performance numbers: `~/Library/Caches/EventHorizon/last-desktop-test.json`. This has timing data, not screenshots.

The legacy identifiers preserve preferences across the app's rename. Settings and the saved image persist; active sessions do not. No Accessibility permission is required for the basic reminder.
