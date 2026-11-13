# Slight Motion

A native macOS menu-bar prototype for scrolling the pane under your pointer with a deliberate thumb–index pinch. Requires macOS 14 or later. Built with SwiftUI, AVFoundation, Vision and Core Graphics.

The app launches **Off**. Enable gesture scrolling, allow Camera and Accessibility, then close the menu. Leave the pointer over the document and show one open hand. **Pinch, then drag left, right, up or down.** Drag left to reveal later columns, right to return to earlier columns, up to reveal later text and down to return to earlier text. Release before repositioning. Movement maps to distance, with no momentum or timed repeats.

The first clear movement after each pinch selects horizontal or vertical scrolling. A diagonal remains pending until one direction is clear. The selected axis stays fixed during that pinch, including reversals and turns. Release and pinch again to switch axes. Pinch confirmation and axis selection produce no scroll, so there is a short initial travel before movement starts. The pointer stays in place and the document app keeps keyboard focus.

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

The menu then includes **Later in 3s**, **Earlier in 3s**, **Content left in 3s** and **Content right in 3s**. Choose one, close the panel, and place the pointer over Safari or a PDF in Preview before the delay expires. The delay starts after the panel closes. Each action sends one 60-pixel event and requires Accessibility access. Camera capture can remain Off. These controls are absent from the normal menu and Release builds.

Local fixtures are included for repeatable checks:

```sh
open -a Safari "Validation/scroll-probe.html"
open -a Safari "Validation/horizontal-scroll-probe.html"
open -a Preview "Validation/preview-scroll-probe.pdf"
```

The article fixture has 60 numbered sections, a separate scrollable sidebar, and live document/sidebar position and document-focus readouts. The horizontal fixture has a table with columns A–AD, 60 rows and a green **O30** cell to track. Its fixed readouts show both scroll axes, focus, wheel events and pointer coordinates. Choose **Go to middle** before testing both directions. Widen the article window if its sidebar is hidden. The six-page Preview fixture supports vertical checks in **View → Continuous Scroll**. For horizontal checks, zoom wider than the window.

See the validation record for completed tests and pending live checks. [TESTING.md](TESTING.md)

## Implementation

- `GestureEngine.swift` contains tuning, aspect-corrected palm measurements, the pinch state machine, per-pinch axis selection and distance mapping.
- `HandCamera.swift` serializes capture and Vision analysis, discards late frames and converts the analysed frames to physical right/up coordinates after resolving rotation and video-output mirroring. Camera frames remain in memory; the app does not save, log or upload them.
- `MotionController.swift` manages permissions, menu interruptions, capture generations, stale results and system suspension.
- `QuartzScrollSink.swift` converts the selected axis and physical direction into one pixel scroll-wheel event at the current pointer location. Horizontal events use wheel 2 and vertical events use wheel 1.

The prototype supports one camera, one visible hand and one scrolling axis per pinch. Axis selection requires 0.015 frame heights of net travel and 1.4× dominance over the other axis, then discards that pre-lock travel. Both axes use frame-height units, a 0.008 spatial hysteresis band, a 2,400-pixel gain and a 60-pixel per-update cap. The earlier vertical prototype's live retest reported steadier relaxed pauses. Comfort and stability with the axis lock still need a live retest.
