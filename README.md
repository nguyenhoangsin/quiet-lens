# QuietLens

Native macOS app that captures a selected screen region, sends it to Gemini, and shows the answer in a floating overlay. Built with SwiftUI and AppKit, following EchoNote's architecture and visual style.

## Build and run

Requires macOS 26+ and Xcode or Swift Command Line Tools with a compatible SDK.

```sh
./scripts/build-app.sh
./scripts/run-app.sh
```

Run `.build/apps/QuietLens.app` for correct permission handling. Builds use two jobs and fall back to Command Line Tools with SDK 26.5 when available. The main window defaults to 660 × 940 pt.

## Setup

1. In **Settings**, enter a Gemini API key and click **Save key**.
2. Click **Allow screen capture** and grant Screen Recording permission. Restart if macOS asks.
3. Click **Choose region** and drag within one display. Press `Esc` to cancel. Minimum size: 20 × 20 pt.
4. Use **Auto → Start** to monitor changes, or **Manual → Ask now** for one request.
5. Edit the prompt and click **Save prompt**. **Use default** restores the example as a draft. Click **Save settings** to apply capture settings.

Closing the main window hides the Dock icon and keeps the app running in the menu bar. Reopening restores the Dock icon. Launch never starts capture automatically; selecting a new region stops monitoring.

## Capture and overlay

- Defaults: **2% change threshold**, **5s capture interval**, **2s stability wait**. Ranges: 0.2–8%, 0.3–30s, and 0.5–10s.
- Auto compares 128 × 96 grayscale fingerprints locally, waits for stability, then captures and checks again before sending. With defaults, detection usually takes 5–10s, plus API latency.
- Successful images become the duplicate baseline. Pause/Start preserves it; changing the prompt, key, or region clears it. Manual always sends when requested.
- Each request sends an in-memory PNG, up to 1800 px on its longest edge, and the saved prompt to Gemini 3.5 Flash-Lite. Requests are serial; screenshots are never queued or saved to disk.
- The 360 × 320 pt overlay sits to the right of the tracked region, then falls back left or inside the display. It is vertically centered and shrinks on small displays.
- Drag the overlay header to move it. Placement survives answers and hide/show; reselection or display layout changes reset it. The overlay never takes keyboard focus.

## Storage and permissions

Settings and prompt use UserDefaults for `com.sinnguyen.QuietLens`. The API key uses one file outside the repository and app bundle:

```text
~/Library/Application Support/QuietLens/APIKey.json
```

Saves atomically replace that file (0600; directory 0700). **Remove** deletes it and removes the directory only if empty. The key survives restarts and rebuilds; it is never shown in the UI. Answers remain in session memory.

Only the selected region and prompt go directly to Google Gemini. Capture excludes QuietLens windows and the cursor. There is no analytics. Display disconnection or resolution changes require reselection.

## Release installer

```sh
./scripts/package-app.sh
```

Creates a separate Release build and a verified DMG in `dist/`, named by version and build architecture. Open the DMG and drag **QuietLens** into **Applications**. Personal keys and settings are excluded.

Builds are ad-hoc signed and not notarized. Rebuilds may require granting Screen Recording permission again. To use a configured signing identity:

```sh
CODESIGN_IDENTITY="Apple Development: …" ./scripts/build-app.sh
```

## Tests and references

```sh
./scripts/test.sh
```

Swift Testing covers change detection, duplicates, API parsing, rate limits, persistence, cancellation, overlay placement, and key-file handling with fake data. Device testing covers permissions, physical displays, focus, and live Gemini responses.

- [Architecture](ARCHITECTURE.md)
- [Icon prompt](Support/IconPrompt.md); assets: `Support/AppIcon.png` and `Support/AppIcon.icns`
- Editable default prompt: `Sources/QuietLens/Resources/DefaultPrompt.txt`
- API: [Gemini model](https://ai.google.dev/gemini-api/docs/models/gemini-3.5-flash-lite), [generateContent](https://ai.google.dev/api/generate-content)
