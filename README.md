# Slight Motion

A native macOS menu-bar prototype for scrolling the pane under your pointer with a deliberate thumb–index pinch. Requires macOS 14 or later. Built with SwiftUI, AVFoundation, Vision and Core Graphics.

The app launches **Off**. Enable gesture scrolling, allow Camera and Accessibility, then close the menu. Leave the pointer over the document, show one open hand, pinch briefly, and move your hand up to reveal later text or down to return to earlier text. Release before repositioning. Movement maps to distance, with no momentum or timed repeats.

Opening the menu pauses output and cancels the current pinch. Close it, open your fingers, and pinch again. The menu-bar hand becomes filled while a pinch is engaged. Disable and Quit stop capture and invalidate pending output.

## Build and run

Open `Slight Motion.xcodeproj`, select the **Slight Motion** scheme and **My Mac**, and run. The project uses the existing local Apple Development signing team. On another Mac, select your own team in Signing & Capabilities.

From the repository directory:

```sh
xcodebuild -project "Slight Motion.xcodeproj" \
  -scheme "Slight Motion" -configuration Debug \
  -destination 'platform=macOS' -derivedDataPath build build

open "build/Build/Products/Debug/Slight Motion.app"
```

The bundle identifier is `uk.whitematter.Slight-Motion`. Hardened Runtime and the Camera entitlement are enabled; App Sandbox is disabled for this local prototype. Keep the same signed app location while testing permissions.

Camera and event-posting permission requests follow an explicit menu action. If access was denied, use **System Settings → Privacy & Security → Camera / Accessibility**, return to the app, and select **Check permissions**. If a permission is switched on in Settings but the app still reports it missing, quit Slight Motion completely and relaunch the same signed build, then check again. This was needed for Accessibility during local validation. A camera failure exposes **Retry camera**. Capture starts only when both permissions are available.

## Tests and external-scroll diagnostics

Run the deterministic unit-test target:

```sh
xcodebuild -project "Slight Motion.xcodeproj" \
  -scheme "Slight Motion" -configuration Debug \
  -destination 'platform=macOS' -derivedDataPath build \
  -only-testing:"Slight MotionTests" test
```

For the separate-app smoke test, quit the running copy, select the shared **Slight Motion Diagnostics** scheme in Xcode, and run. This scheme launches Debug with `--scroll-diagnostics`. Alternatively, launch the Debug build from Terminal:

```sh
open "build/Build/Products/Debug/Slight Motion.app" --args --scroll-diagnostics
```

The menu then includes **Later in 3s** and **Earlier in 3s**. Choose one, close the panel, and place the pointer over Safari or a PDF in Preview before the delay expires. The delay starts after the panel closes. Each action sends one 60-pixel event and requires Accessibility access. Camera capture can remain Off. These controls are absent from the normal menu and Release builds.

Local fixtures are included for repeatable checks:

```sh
open -a Safari "Validation/scroll-probe.html"
open -a Preview "Validation/preview-scroll-probe.pdf"
```

The Safari fixture has 60 numbered sections, a separate scrollable sidebar, and live document/sidebar position and document-focus readouts. Choose **Go to middle** before testing both directions; widen the window if the sidebar is hidden. The Preview fixture has six pages; select continuous scrolling before testing.

See [TESTING.md](TESTING.md) for verified results and the pending live acceptance checklist. A successful build and unit tests do not establish the cross-app scrolling milestone.

## Implementation

- `GestureEngine.swift` contains all initial tuning, aspect-corrected landmark measurements, the pinch state machine and distance mapping.
- `HandCamera.swift` serializes capture and Vision analysis, discards late frames and emits timestamped landmarks. Camera frames remain in memory; the app does not save, log or upload them.
- `MotionController.swift` manages permissions, menu interruptions, capture generations, stale results and system suspension.
- `QuartzScrollSink.swift` maps positive internal movement to a negative Quartz vertical pixel delta and posts at the current pointer location. Safari later-direction and Preview later/earlier diagnostic pulses have been verified. The user also confirmed live pinch scrolling and open-hand repositioning in Preview; the extended acceptance checklist and Natural Scrolling comparisons remain pending.

The prototype supports one camera, one visible hand and vertical scrolling. The spatial filter ignores movement inside a 0.008-image-height band and scrolls only the portion beyond it. This adds some travel before scrolling starts or reverses; gain is unchanged. A live retest confirmed steadier relaxed pauses while deliberate scrolling still worked. Small page movement after a stroke is still possible. See [TESTING.md](TESTING.md) for the tuning record and remaining checks.
