# Mini Desk for iOS

[简体中文](README.md) | **English**

The native mobile companion for Mini Desk: capture it now, continue on your desktop later.

Built with SwiftUI for mobile only. Compatible with the current mobile capture protocol of [Mini Desk for desktop](https://github.com/xiangjianan/mini-desk), with no changes required to the desktop app or server.

## Features

- Pair by scanning a desktop QR code, entering a 12-character pairing code, or pasting a pairing link.
- Validate server status before pairing and store the pairing code in the device Keychain.
- Send reminders (one item per line) or quick notes (one item per draft, preserving line breaks). Oversized text is rejected instead of silently truncated.
- Send the original text by default, with optional server-side AI cleanup and reminder time recognition.
- Automatically save drafts and retain local send history and failed items.
- Capture uses a full-page note editor: tap empty space to type, swipe down to dismiss the keyboard interactively, and clear the text after sending.
- Switch between reminders and quick notes at the top. The bottom tab bar hides while the keyboard is visible; message history appears only on the history screen.
- Tabs are ordered Pairing / Capture / History. Paired devices open Capture by default. Unpaired devices show a separate full-screen pairing entry with the tab bar hidden. Normal app access is blocked when pairing is missing or invalid. Switching tabs provides light haptic feedback.
- Retry failed items manually using their original message ID and workspace. Changing the pairing does not send old messages to a different desktop.
- System Liquid Glass tab bars and toolbars, `.glass` / `.glassProminent` buttons, and a few `glassEffect` decorations.
- Follow the system light/dark appearance, with support for Dynamic Type, VoiceOver, iPhone, and iPad.

## Open and run

1. Open `MiniDesk.xcodeproj` in **Xcode 26 or later**. This project was build-validated with Xcode 27 / the iOS 27 SDK. The minimum deployment target is iOS 26.
2. Select the `MiniDesk` target and choose your own Team in Signing & Capabilities. Change the Bundle Identifier to a unique personal value if needed.
3. Select an iPhone / iPad or a simulator with an installed runtime, then run the app.
4. In [Mini Desk for desktop](https://minidesk.online), open “手机速记” (Mobile Capture) from the workspace menu to obtain a code or QR code. Pair on the app's Pairing screen.
5. Enter text, choose a reminder or quick note, and send. The desktop app fetches messages periodically, or you can sync manually on the desktop.

QR scanning requires a camera on a physical device; enter the pairing code manually on simulators without a camera. Existing HTTPS pairing links support scanning and pasting. Universal Links are not configured. The custom link `minidesk://pair#inbox=YOUR_PAIRING_CODE` opens the app's Pairing screen directly.

The committed Xcode project can be opened directly; installing XcodeGen first is unnecessary. To update the project configuration, run:

```sh
brew install xcodegen
xcodegen generate
```

## Validation

```sh
swift test
xcodebuild -project MiniDesk.xcodeproj -scheme MiniDesk \
  -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath DerivedData CODE_SIGNING_ALLOWED=NO build
xcodebuild -project MiniDesk.xcodeproj -scheme MiniDesk \
  -sdk iphoneos -destination 'generic/platform=iOS' \
  -derivedDataPath DerivedData CODE_SIGNING_ALLOWED=NO build
```

2026-10-01: All 9 automated tests passed (the parameterized pairing-error test covers 3 scenarios). Dual-architecture builds with the iOS Simulator SDK and the arm64 device build passed. Tests cover code normalization, SHA-256 compatibility with the web protocol, nested JSON, timestamps, the UTC+8 time zone, character limits, HTTP status classification, and URLSession requests/responses.

**Runtime and live-service integration validation are still pending**: the development environment had no iOS Simulator runtime installed, and TLS connections to the production relay failed from the current network. SDK compilation does not replace UI execution, camera permission checks, or device send/receive validation. Complete the following acceptance checks on a physical device that can reach the relay:

- Pair with a valid code; reject unknown and revoked codes.
- Allow/deny camera permission for QR scanning; paste an HTTPS pairing link.
- Send single-line and multi-line reminders and notes, then verify the content after desktop sync.
- Fail a send in airplane mode, restart the app, and retry; verify that drafts and pending records persist.
- Verify that old pending items are not sent to a new workspace after switching workspaces.
- Check the AI toggle, relative reminder times, light/dark appearance, and large text.

## Protocol and delivery semantics

The protocol follows `src/sync/`, `MobileInboxCapture.vue`, and `server/app.py` at upstream commit `dc13c6cd3db0b863cec523a6dc9fb3f0717bfc10`.

Default endpoint: `https://relay.minidesk.online:8443`. Change `RelayClient.defaultURL` in `MiniDesk/Core/Protocol.swift` to use another endpoint.

- 12-character Crockford Base32 codes, with whitespace removed and letters uppercased: `I/L → 1`, `O → 0`.
- The routing key is the SHA-256 hex digest of the normalized pairing code.
- Pairing: `GET /inbox/{hash}/status`. Only `active` is accepted. Network errors preserve the existing pairing.
- Sending: `POST /inbox/{hash}` with an outer `{id, payload}` object. `payload` is a JSON **string** containing `kind`, `text`, millisecond `createdAt`, boolean `polish`, and `tzOffsetMinutes` with eastward offsets positive.
- A 15-second timeout, with distinct handling for 400 / 404 / 409 / 410 / 413 / 429 and network errors.
- “Received by relay” means only that the HTTP request succeeded. The server subsequently stores/processes the message in the background; the current protocol provides no desktop receipt acknowledgment. The desktop typically fetches every 5 minutes and also fetches when focus returns.
- No automatic retries or background sending. Users retry pending records on the history screen; losing connectivity does not discard unsent content.
- The same ID lets the server overwrite duplicates. However, if the desktop already fetched that ID after a network timeout, retrying may deliver it again. The current protocol cannot guarantee end-to-end exactly-once delivery.
- Natural-language reminder time recognition uses the existing server-side AI processing. With AI disabled, only the original text is sent; no local notifications or date picker are added.

## Data

Pairing codes use the Keychain accessibility attribute `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`. Drafts and AI preferences are stored in the app's own UserDefaults. Send history is stored in Application Support with iOS complete file protection. Requests use system HTTPS with certificate validation enabled.

**The current protocol is not end-to-end encrypted**: the relay can read messages, and the server-side model processes content when AI is enabled. This app contains no ads, analytics SDKs, or tracking. A PrivacyInfo.xcprivacy file is included. Before release, the service operator must confirm actual data retention and App Store privacy questionnaire answers, and provide a formal privacy policy.

Automatic signing is configured, and build `1.0.0 (2)` has been uploaded to App Store Connect. The app has not been submitted for review or released. See the [release checklist](docs/app-store-readiness.md) for current status and remaining work. The [privacy policy](https://xiangjianan.github.io/minidesk-ios/) is public.
