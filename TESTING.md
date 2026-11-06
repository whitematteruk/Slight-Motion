# Prototype test record

Recorded 6 November 2026.

| Environment | Value |
| --- | --- |
| Mac | MacBook Air, Mac14,15, Apple M2, 24 GB RAM |
| macOS | 26.7.2 (25G332) |
| Xcode | 27.0 (27A266a) |
| Deployment target | macOS 14.0 |
| Signing | Existing local Apple Development identity; Hardened Runtime; Camera entitlement; App Sandbox off |
| External scroll verification | Safari later pulse; Preview later/earlier pulses and live pinch scroll/open-hand return confirmed; revised-filter retest reported steadier pauses with scrolling preserved |
| Safari | 27.0 (21625.1.29.18.24) |
| Preview | 11.0 (1113.5.3) |

## Verified

- Debug and Release `xcodebuild build` succeeded with local signing. Release rebuilds also passed after the permission-recovery hint and the 0.008 spatial-filter revision; the revised Release signature is valid.
- Debug and Release local signatures are valid. Generated permission metadata was checked; deployment target is macOS 14, Camera entitlement is present and App Sandbox is off.
- After the pause-stability revision, the full Xcode unit-test run succeeded: **19 tests passed** in `Slight MotionTests` (16 gesture/lifecycle tests and 3 Quartz adapter tests).
- Synthetic timestamped landmarks cover open-hand arming; zero output on engagement; pinch-threshold jitter; equal strokes at 30/60 Hz below the cap; slow movement across the deadband; reversal; constant-height and horizontal movement; release-frame discard; return strokes; tracking loss; capture gaps; stale/out-of-order results; caps; fractional reset; pixel aspect correction; and late-result rejection after disable/interruption. The revised tests also cover a two-second hold with varying heights, noise near the band edge, and bounded settling after strokes in both directions. These synthetic checks do not establish comfortable-pause performance on camera.
- Real `CGEvent` construction checks verify pixel units, vertical direction mapping, zero other axes, specified location, no momentum and zero-event suppression. These checks construct events without posting them to another process.
- The Release menu panel was visually inspected through computer use after the desktop became available. Layout was correct, launch state was **Off**, and no permission requests appeared before an explicit action.
- Camera and Accessibility were manually granted. Accessibility remained denied to the running process despite the Settings switch being on; quitting and relaunching resolved it. macOS authorization diagnostics then confirmed `CameraAllowed` and `PostEventAllowed` for the relaunched process.
- The shared **Slight Motion Diagnostics** scheme launches Debug with `--scroll-diagnostics`; the ordinary scheme and Release menu keep the pulse controls hidden. After validation, the diagnostic process was stopped, no Slight Motion process remained, and Xcode was returned to the ordinary scheme.
- Real cross-process event posting was observed from the native Slight Motion process to Safari: after the user chose **Later in 3s**, the local article moved toward later material while its document-focus readout remained **YES** before and after. Gesture scrolling stayed Off for this test.
- The user confirmed that both **Later in 3s** and **Earlier in 3s** moved the six-page PDF in Preview in the expected directions. Native computer-use inspection found the same page and scrollbar position before and after the opposite-direction pair, with the document container focused afterward. This passes the user-reported Preview pulse routing/direction smoke check; individual intermediate displacements were not measured.
- With gesture scrolling enabled, the user confirmed live pinch scrolling of the Preview PDF and open-hand repositioning. After reporting comfortable-pause drift/jitter, the user retested the revised filter and answered: “Steadier, and scrolling still works.” This confirms subjective stability improvement with deliberate scrolling preserved; it does not establish zero residual drift.

The desktop was locked during the initial UI validation attempt; GUI validation resumed after it became available. The native computer-use connection could not attach to the menu-only app until its panel was opened manually; that attachment limitation was not an app crash. The integrated camera-to-gesture-to-external-scroll milestone has been demonstrated on the real Mac. The extended acceptance checks below remain pending.

For permission recovery, grant access in **System Settings → Privacy & Security → Camera / Accessibility**, return and select **Check permissions**. If the app still reports missing access, quit it completely and relaunch the same signed build. Keep its location and signing identity stable during validation.

## Live external-scroll smoke

With gesture scrolling Off, the user selected **Later in 3s**, then placed the pointer and clicked over the local Safari article during the delay. The user reported that the text moved. Computer-use inspection recorded:

| Observation | Before | After |
| --- | --- | --- |
| Document scrollY | 8,165 px | 8,285 px |
| Document focus | YES | YES |
| Sidebar scrollY | 0 px | 0 px |

The observed document displacement was +120 CSS pixels toward later text. The action requests a 60-pixel toward-later delta through Quartz; receiving-app displacement can differ from commanded units. Posted-event count and CSS-to-Quartz scale were not independently measured, so this result does not establish an exact one-event pixel ratio. The unchanged sidebar readout supports document-pane routing for this trial. Pointer position was not independently instrumented.

This verifies separate-process event delivery and the later-direction sign in Safari.

In Preview, the user reported that the later pulse moved the PDF toward later content and the earlier pulse moved it back. Native computer-use inspection recorded the following before the pair and after both pulses:

| Preview observation | Before pair | After pair |
| --- | --- | --- |
| Page | 3 of 6 | 3 of 6 |
| Normalized scrollbar position | 0.4002832197954291 | 0.4002832197954291 |

The final focused UI element was the document container. The unchanged final position corroborates the reported return after the two directions; it does not quantify either intermediate movement or independently establish uninterrupted focus. The Preview pulse routing/direction smoke result is a user-reported pass with this final-position evidence. Pointer position during the pulses was not independently measured.

Safari earlier scrolling, sidebar targeting, Natural Scrolling on/off and stationary pointer verification remain pending.

## Live gesture integration

After enabling camera gesture scrolling, the user confirmed that a live pinch moved the PDF in Preview: “Scrolling works.” Open-hand lowering/repositioning also passed by user report. These results remain valid.

An initial two-second controlled hold was reported still, but a later comfortable-pause trial revealed drift/jitter. That later feedback supersedes the hold pass. The original positional deadband accepted an entire displacement once it crossed 0.003 of image height, so small landmark changes could become visible page steps. Tests with perfectly constant heights passed without covering this pattern.

After the spatial-filter revision, the user repeated the PDF test with a relaxed pinched-hand pause and reported: “Steadier, and scrolling still works.” The comfortable-pause improvement and preserved deliberate scrolling are therefore confirmed by user report. Residual movement was not quantified.

This demonstrates camera input, gesture recognition and event delivery working together in a separate app. It does not establish zero drift, five cycles in each direction, slow movement, reversal, horizontal-only motion, camera loss or returning already pinched. The revised filter also passes the deterministic regression tests. Gain remains unchanged.

## Current tuning

All values live in `GestureConfiguration.prototype` in `Slight Motion/GestureEngine.swift`.

| Parameter | Current value |
| --- | --- |
| Required joint confidence | ≥ 0.5 |
| Close / open pinch ratio | ≤ 0.25 / ≥ 0.40 |
| Continuous close to engage | 100 ms |
| Maximum capture gap / observation age | 150 ms / 150 ms |
| Minimum palm width | 12 oriented image pixels |
| Gain | 2,400 scroll pixels per full image height |
| Positional deadband | 0.008 of image height; spatial hysteresis, output only beyond the band |
| Per-update cap | 60 pixels, excess discarded |
| Capture request | 640 × 480 and 30 fps where supported |
| Quartz sign | Positive movement toward later text → negative `wheel1`; Safari later pulse and Preview later/earlier pulses verified; Natural Scrolling comparisons pending |

The previous 0.003 deadband was replaced with a 0.008 spatial hysteresis radius: 3.84 camera-image pixels at 480 pixels high. The filtered height stays fixed while the measured height remains inside the band; only displacement beyond its edge becomes scroll output. There is no temporal smoothing or gain change. At the current gain, the ignored travel corresponds to about 19.2 scroll units when starting and about 38.4 when reversing an established stroke. Receiving-app page displacement can differ from commanded units.

The filter reduces small fluctuations but does not guarantee a motionless page during every relaxed hold. After a stroke, noise crossing the band can still produce bounded page movement. Deterministic regression tests and the Release rebuild pass; the live retest confirmed steadier relaxed pauses with scrolling preserved by user report. No accidental-scroll trial has been completed; orientation handling is unmeasured, and seated distance and lighting were not recorded.

## Pending live checklist

Use the **Slight Motion Diagnostics** scheme and its Debug diagnostic pulse first; camera capture may stay Off. After choosing a pulse, close the panel and place the pointer over the target pane during the three-second delay. Then enable camera input and test at normal seated distance. Keep Safari and Preview away from document scroll limits.

`Validation/scroll-probe.html` provides a local 60-section Safari document and independently scrollable sidebar, with fixed document/sidebar scroll-position and document-focus readouts. Choose **Go to middle** and keep the Safari window wide enough to show the sidebar. `Validation/preview-scroll-probe.pdf` provides a six-page Preview fixture; use Preview's continuous-scroll mode. Both fixtures were used in the external pulse smoke checks above, and live hand-driven scrolling was confirmed in the Preview PDF. The detailed camera gesture checks below remain pending.

| Check | Required observation | Result |
| --- | --- | --- |
| External pulse | One later/earlier pulse scrolls Safari and Preview; app focus and pointer position stay unchanged | Safari later direction/focus observed; Preview later/earlier user-reported pass and final position corroborated; Safari earlier and stationary-pointer verification pending |
| Live gesture integration | Camera-observed pinch movement scrolls a separate app on the real Mac | Passed in Preview by user report: “Scrolling works” |
| Full interaction | Five grab–move–release cycles in each direction in the middle of a Safari article and a multi-page Preview PDF | Basic Preview gesture scrolling confirmed; full five-cycle trials in both apps pending |
| Pinch and reset | Closing fingers without palm movement emits zero; open-hand return stroke emits zero; each new pinch anchors at its current height | Open-hand lowering/repositioning passed by user report; closure-only and fresh-anchor trials pending |
| Fine control | Slow stroke moves text; reversing a held pinch reverses direction; a relaxed two-second pause has no visible drift; horizontal-only movement produces no scroll | Revised filter: user reported steadier relaxed pauses and deliberate scrolling still working. Zero residual drift and dedicated slow/reversal/horizontal trials remain unverified. |
| Loss and reacquisition | Cover camera or leave view mid-stroke; stop without jump/tail; return already pinched remains inactive until open then close | Pending |
| Ordinary desk use | Type and gesture for 60 seconds; record unintended movement, target zero | Pending |
| Routing and direction | Pointer over sidebar then document routes only to that pane; up reveals later text and down earlier text with Natural Scrolling both on and off | Pending |
| Menu lifecycle | Open menu mid-pinch stops output; leave menu open beyond four seconds without false camera failure; reopen/close repeatedly and require a fresh pinch | Pending |
| Permissions | Deny Camera and Accessibility separately; identify missing permission; grant in Settings, return and retry | Grant and quit/relaunch recovery observed; separate denial trials pending |
| Camera failure | Disconnect or interrupt camera; output stops; Retry recovers with a fresh open hand | Pending |
| Disable / Quit / relaunch | Disable mid-pinch suppresses late output and releases camera; Quit releases camera; relaunch starts Off | Off launch observed; live mid-pinch and camera-release checks pending |

For each completed run, record app versions, document/page, camera, seated distance, lighting, Natural Scrolling setting, tuning changes and observed issues here. If direction is reversed, verify the single sign mapping in `QuartzScrollSink` before adjusting gain.
