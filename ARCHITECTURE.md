# QuietLens architecture

Native Swift package following EchoNote: Models, Services, ViewModels, and Views; SwiftUI with AppKit integration; signed app packaging.

```text
RegionSelector → ScreenRegion → ConfigurationStore
ScreenCaptureManager → ImageProcessor → ContentChangeDetector
                                               ↓ stable
                                    final capture and check
                                               ↓
PromptManager + APIKeyManager → GeminiClient → QuietLensViewModel
                                               ↓
                               QuietLensView + AnswerOverlay
```

## Components

- **ScreenRegion / LensSettings:** validated display-local coordinates and bounded capture settings.
- **RegionSelector:** temporary selection panels; converts AppKit coordinates to the display's top-left origin.
- **ScreenCaptureManager:** ScreenCaptureKit cropping, permission checks, display validation, and exclusion of QuietLens windows. Preparation is scoped to the current revision.
- **ImageProcessor:** creates 128 × 96 grayscale fingerprints and PNGs with a maximum 1800 px edge, off the main actor.
- **ContentChangeDetector:** compares stable anchors, debounces cumulative changes, and checks the final capture. Only successful responses commit a duplicate baseline.
- **PromptManager / ConfigurationStore:** resource-backed default prompt and UserDefaults persistence. The prompt remains editable.
- **APIKeyManager:** atomic storage at `~/Library/Application Support/QuietLens/APIKey.json` (0600; directory 0700). Removal clears the file and empty directory. UI receives key presence only.
- **GeminiClient:** ephemeral URLSession, header authentication, inline PNG, and Gemini 3.5 Flash-Lite. Parses visible text and handles blocked output, HTTP errors, and Retry-After.
- **QuietLensViewModel:** main-actor coordinator for serial capture, requests, retries, and publication. A UUID revision rejects stale results. Manual requests bypass duplicate suppression.
- **AnswerOverlay / OverlayPlacement:** passive NSPanel, 360 × 320 pt, right/left/display-edge placement, and vertical centering. Native header dragging preserves position until reselection or display layout changes.
- **QuietLensView / LensSettingsView:** main controls and settings drafts. Save prompt uses applied capture settings; Save settings applies the full draft. Key changes apply immediately.
- **QuietLensApp:** main window and menu bar. Opening shows the Dock icon; closing switches to background operation. Overlay panels never change activation policy.

## Lifecycle

Launch restores settings without capturing. Start or Ask validates permission, region, and key. Auto samples locally, waits for stability, recaptures, and awaits one response. Captures never overlap API requests.

Stop invalidates the revision before cancellation. Region changes stop monitoring and clear the answer. Saving settings restarts active Auto with a new snapshot. Prompt, key, or region changes clear the duplicate baseline; Pause/Start preserves it.

Requests use a 45s timeout and 60s resource timeout. Temporary errors retry with backoff up to 60s; rate limits honor Retry-After (5–300s, default 30s). Retries capture current content. Invalid requests, keys, permissions, or displays stop Auto and show an inline error.

## Packaging and validation

Build scripts limit compilation to two jobs and sign resource bundles before the app. Packaging creates a separate Release build, an Applications shortcut, a compressed DMG, and a SHA-256 checksum.

Tests inject fake capture, API, storage, and persistence. Real permissions, display geometry, focus, and Gemini responses require device testing. Tests use no production secrets.
