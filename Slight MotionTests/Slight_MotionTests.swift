import Foundation
import Testing
@testable import Slight_Motion

private struct RecordingScrollSink {
    var movements: [ScrollMovement] = []
    mutating func receive(_ value: ScrollMovement?) {
        if let value { movements.append(value) }
    }
    var values: [Int] { movements.map(\.pixels) }
    var total: Int { values.reduce(0, +) }
}

private func landmarks(
    ratio: Double = 0.20,
    height: Double = 0.5,
    confidence: Double = 1,
    width: Double = 640,
    imageHeight: Double = 480,
    horizontalOffset: Double = 0
) -> HandLandmarks {
    HandLandmarks(
        thumbTip: HandPoint(x: 0.5 + horizontalOffset - ratio * 0.2, y: height + 0.1, confidence: confidence),
        indexTip: HandPoint(x: 0.5 + horizontalOffset, y: height + 0.1, confidence: confidence),
        indexMCP: HandPoint(x: 0.4 + horizontalOffset, y: height, confidence: confidence),
        littleMCP: HandPoint(x: 0.6 + horizontalOffset, y: height, confidence: confidence),
        imageWidth: width,
        imageHeight: imageHeight
    )
}

private struct Harness {
    var session: GestureSession
    var generation: UInt64
    var time = 10.0
    var sink = RecordingScrollSink()
    var imageWidth = 640.0
    var imageHeight = 480.0

    init(configuration: GestureConfiguration = .prototype) {
        var session = GestureSession(configuration: configuration)
        generation = session.enable()
        self.session = session
    }

    @discardableResult
    mutating func frame(
        ratio: Double = 0.20,
        height: Double = 0.5,
        after interval: Double = 1.0 / 30,
        confidence: Double = 1,
        horizontalOffset: Double = 0
    ) -> ScrollMovement? {
        sample(landmarks(ratio: ratio, height: height, confidence: confidence,
                         width: imageWidth, imageHeight: imageHeight,
                         horizontalOffset: horizontalOffset), after: interval)
    }

    @discardableResult
    mutating func sample(_ observation: HandLandmarks?,
                         after interval: Double = 1.0 / 30) -> ScrollMovement? {
        time += interval
        let output = session.process(
            observation: observation,
            timestamp: time, now: time, generation: generation
        )
        sink.receive(output)
        return output
    }

    /// Existing filter regressions start locked at the requested movement baseline.
    /// Passing nil exercises the real pending-axis state after pinch confirmation.
    mutating func engage(at height: Double = 0.5, horizontalOffset: Double = 0,
                         axis: ScrollAxis? = .vertical) {
        let distance = session.engine.configuration.axisLockDistance
        let startHeight = axis == .vertical ? height - distance : height
        let startOffset = axis == .horizontal ? horizontalOffset - distance * imageHeight / imageWidth : horizontalOffset
        frame(ratio: 0.5, height: startHeight, horizontalOffset: startOffset)
        frame(height: startHeight, horizontalOffset: startOffset)
        frame(height: startHeight, after: 0.05, horizontalOffset: startOffset)
        frame(height: startHeight, after: 0.05, horizontalOffset: startOffset)
        if axis != nil {
            frame(height: height, horizontalOffset: horizontalOffset)
        }
    }

    /// Both components use frame-height units, as required by the physical-motion model.
    @discardableResult
    mutating func move(right: Double = 0, up: Double = 0,
                       ratio: Double = 0.20, after interval: Double = 1.0 / 30) -> ScrollMovement? {
        frame(ratio: ratio, height: 0.5 + up, after: interval,
              horizontalOffset: right * imageHeight / imageWidth)
    }
}

struct GestureEngineTests {
    @Test func closedHandCannotArmUntilItOpens() {
        var harness = Harness()
        for _ in 0..<12 { harness.frame(height: 0.6) }
        #expect(harness.session.engine.state == .waitingForOpen)
        #expect(harness.sink.values.isEmpty)
        harness.frame(ratio: 0.5)
        #expect(harness.session.engine.state == .ready)
        harness.frame()
        #expect(harness.session.engine.state == .confirmingPinch)
        harness.frame(after: 0.05)
        #expect(!harness.session.engine.isEngaged)
        harness.frame(after: 0.05)
        #expect(harness.session.engine.isEngaged)
        #expect(harness.sink.values.isEmpty)
    }

    @Test func engagementAnchorsAfterClosingWithoutOutput() {
        var harness = Harness()
        harness.frame(ratio: 0.5, height: 0.2)
        harness.frame(height: 0.3)
        harness.frame(height: 0.4, after: 0.05)
        harness.frame(height: 0.5, after: 0.05)
        #expect(harness.session.engine.isEngaged)
        #expect(harness.sink.values.isEmpty)
        #expect(harness.session.engine.lockedAxis == nil)
        harness.frame(height: 0.518)
        #expect(harness.session.engine.lockedAxis == .vertical)
        #expect(harness.sink.values.isEmpty)
        harness.frame(height: 0.536)
        #expect(harness.sink.values == [24])
    }

    @Test func thresholdJitterBreaksConfirmationButNotAnEngagedPinch() {
        var harness = Harness()
        harness.frame(ratio: 0.5)
        harness.frame(ratio: 0.24)
        harness.frame(ratio: 0.26, after: 0.06)
        #expect(harness.session.engine.state == .ready)
        harness.frame(ratio: 0.24)
        harness.frame(ratio: 0.24, after: 0.06)
        #expect(!harness.session.engine.isEngaged)
        harness.frame(ratio: 0.24, after: 0.04)
        #expect(harness.session.engine.isEngaged)
        harness.frame(ratio: 0.39, height: 0.518)
        #expect(harness.session.engine.isEngaged)
        #expect(harness.sink.values.isEmpty)
        harness.frame(ratio: 0.39, height: 0.536)
        #expect(harness.sink.values == [24])
        harness.frame(ratio: 0.41, height: 0.8)
        #expect(harness.session.engine.state == .ready)
        #expect(harness.sink.values == [24])
    }

    @Test func equalStrokesAtThirtyAndSixtyFramesPerSecond() {
        func stroke(frames: Int) -> Int {
            var harness = Harness()
            harness.engage(at: 0.4)
            for index in 1...frames {
                harness.frame(height: 0.4 + 0.12 * Double(index) / Double(frames), after: 1.0 / Double(frames))
            }
            #expect(harness.sink.values.allSatisfy { $0 > 0 && $0 < 60 })
            return harness.sink.total
        }
        let thirty = stroke(frames: 30)
        let sixty = stroke(frames: 60)
        let expected = (0.12 - GestureConfiguration.prototype.positionalDeadband) * 2_400
        #expect(abs(Double(thirty) - expected) < 1)
        #expect(abs(Double(sixty) - expected) < 1)
        #expect(abs(thirty - sixty) <= 1)
    }

    @Test func aSlowStrokeAccumulatesWithoutAVelocityThreshold() {
        var harness = Harness()
        harness.engage()
        for index in 1...16 { harness.frame(height: 0.5 + 0.0005 * Double(index)) }
        #expect(harness.sink.values.isEmpty)
        harness.frame(height: 0.5085)
        #expect(harness.sink.values == [1])
        for index in 18...20 { harness.frame(height: 0.5 + 0.0005 * Double(index)) }
        #expect(harness.sink.total == 4) // (0.010 - 0.008) * 2,400, with fraction retained.
        harness.frame(height: 0.53)
        #expect(harness.sink.total == 52)
        #expect(harness.sink.values.allSatisfy { $0 > 0 })

        // A still slower ramp must also accumulate, regardless of elapsed time.
        var slower = Harness()
        slower.engage()
        for index in 1...300 { slower.frame(height: 0.5 + 0.0001 * Double(index)) }
        #expect(slower.sink.total == 52)
    }

    @Test func sameStrokeCanReverseAndHoldingNeverRepeats() {
        var harness = Harness()
        harness.engage()
        harness.frame(height: 0.518)
        #expect(harness.sink.values == [24])
        // Reverse through the opposite side of the tolerance band before output reverses.
        harness.frame(height: 0.51)
        harness.frame(height: 0.502)
        #expect(harness.sink.values == [24])
        harness.frame(height: 0.492)
        #expect(harness.sink.values == [24, -24])
        for _ in 0..<60 { harness.frame(height: 0.492) }
        #expect(harness.sink.values == [24, -24])
        for offset in [0.1, -0.1, 0.05] {
            harness.frame(height: 0.492, horizontalOffset: offset)
        }
        #expect(harness.sink.values == [24, -24])
    }

    @Test func comfortablePauseToleratesVaryingHeightForTwoSeconds() {
        var harness = Harness()
        harness.engage()
        let offsets = [0.006, -0.005, 0.003, -0.006, 0.001, 0.005, -0.004]
        for index in 0..<60 {
            harness.frame(height: 0.5 + offsets[index % offsets.count])
        }
        #expect(harness.session.engine.isEngaged)
        #expect(harness.sink.values.isEmpty)
    }

    @Test func jitterNearTheBoundaryDoesNotJumpOrAlternate() {
        var harness = Harness()
        harness.engage()
        for height in [0.5079, 0.5081, 0.5078, 0.5082, 0.5079, 0.5081] {
            harness.frame(height: height)
        }
        #expect(harness.sink.values.isEmpty) // Only 0.0002 accepted height: less than one scroll pixel.
        harness.frame(height: 0.51)
        #expect(harness.sink.values == [4]) // No full deadband-sized jump at onset.
        for height in [0.5099, 0.5101, 0.5098, 0.5102, 0.5099] {
            harness.frame(height: height)
        }
        #expect(harness.sink.values.allSatisfy { $0 > 0 })
        #expect(harness.sink.total == 5)
    }

    @Test func jitterAfterAStrokeSettlesWithinABoundInBothDirections() {
        for direction in [-1.0, 1.0] {
            var harness = Harness()
            harness.engage()
            let stoppedHeight = 0.5 + direction * 0.03
            harness.frame(height: stoppedHeight)
            let strokeTotal = harness.sink.total
            let countAfterStroke = harness.sink.values.count
            let offsets = [0.003, -0.006, 0.006, -0.004, 0.002, -0.003]
            for index in 0..<60 {
                harness.frame(height: stoppedHeight + offsets[index % offsets.count])
            }
            let settlingValues = Array(harness.sink.values.dropFirst(countAfterStroke))
            // The output starts at the stroke's band edge. A new outward extreme
            // may advance it once; this is bounded settling, not zero-jitter proof.
            #expect(settlingValues.allSatisfy { Double($0) * direction > 0 })
            #expect(abs(harness.sink.total - strokeTotal) <= 15)
            let settledCount = harness.sink.values.count
            for index in 0..<60 {
                harness.frame(height: stoppedHeight + offsets[index % offsets.count])
            }
            #expect(harness.sink.values.count == settledCount)
        }
    }

    @Test func releaseDiscardsLargeMovementAndReturnStroke() {
        var harness = Harness()
        harness.engage()
        harness.frame(height: 0.518)
        harness.frame(ratio: 0.5, height: 0.8)
        harness.frame(ratio: 0.5, height: 0.2)
        #expect(harness.sink.values == [24])
        harness.frame(height: 0.2)
        harness.frame(height: 0.2, after: 0.1)
        #expect(harness.session.engine.isEngaged)
        harness.frame(height: 0.218)
        #expect(harness.sink.values == [24]) // Fresh pinch locks without replaying pre-lock travel.
        harness.frame(height: 0.236)
        #expect(harness.sink.values == [24, 24])
    }

    @Test func captureGapRequiresOpenBeforeReengaging() {
        var harness = Harness()
        harness.engage()
        harness.frame(height: 0.518)
        harness.frame(height: 0.8, after: 0.151)
        #expect(harness.session.engine.state == .waitingForOpen)
        harness.frame(height: 0.6)
        harness.frame(height: 0.4, after: 0.12)
        #expect(harness.sink.values == [24])
        harness.engage(at: 0.4)
        harness.frame(height: 0.418)
        #expect(harness.sink.values == [24, 24])
    }

    @Test func invalidJointAndMissingObservationImmediatelyCancel() {
        var harness = Harness()
        harness.engage()
        harness.frame(height: 0.8, confidence: 0.49)
        #expect(harness.session.engine.state == .waitingForOpen)
        harness.frame(height: 0.6)
        #expect(harness.sink.values.isEmpty)
        harness.engage()
        let output = harness.session.process(observation: nil, timestamp: harness.time + 0.03,
                                             now: harness.time + 0.03, generation: harness.generation)
        #expect(output == nil)
        #expect(!harness.session.engine.isEngaged)
    }

    @Test func staleAndOutOfOrderFramesCannotMoveOrArm() {
        var harness = Harness()
        harness.engage()
        let stale = harness.session.process(observation: landmarks(height: 0.8), timestamp: harness.time + 0.03,
                                            now: harness.time + 0.20, generation: harness.generation)
        #expect(stale == nil)
        #expect(harness.session.engine.state == .waitingForOpen)
        harness.engage()
        let old = harness.session.process(observation: landmarks(ratio: 0.5, height: 0.8),
                                          timestamp: harness.time - 0.01, now: harness.time,
                                          generation: harness.generation)
        #expect(old == nil)
        #expect(harness.session.engine.state == .waitingForOpen)
    }

    @Test func capDiscardsExcessAndFractionalRemainderResetsOnRelease() {
        var harness = Harness()
        harness.engage()
        harness.frame(height: 0.7)
        for _ in 0..<5 { harness.frame(height: 0.7) }
        #expect(harness.sink.values == [60])
        harness.frame(height: 0.703)
        #expect(harness.sink.values == [60, 7])
        harness.frame(ratio: 0.5, height: 0.5)
        harness.engage()
        harness.frame(height: 0.511)
        #expect(harness.sink.values == [60, 7, 7])
    }

    @Test func aspectCorrectedPixelDistanceAndPalmHeight() {
        // Diagonal palm = hypot(128, 96) pixels; normalized distances would distort the ratio.
        let hand = HandLandmarks(
            thumbTip: HandPoint(x: 0.5, y: 0.5, confidence: 1),
            indexTip: HandPoint(x: 0.5, y: 0.6, confidence: 1),
            indexMCP: HandPoint(x: 0.4, y: 0.3, confidence: 1),
            littleMCP: HandPoint(x: 0.6, y: 0.5, confidence: 1),
            imageWidth: 640, imageHeight: 480
        )
        let measured = hand.measurements(configuration: .prototype)
        let expectedRatio = 48.0 / hypot(128.0, 96.0)
        #expect(abs((measured?.ratio ?? -1) - expectedRatio) < 1e-9)
        #expect(abs((measured?.palm.y ?? -1) - 0.4) < 1e-9)
        #expect(abs((measured?.palm.x ?? -1) - 2.0 / 3.0) < 1e-9)
        let tinyHand = landmarks(width: 20)
        #expect(tinyHand.measurements(configuration: .prototype) == nil)
    }

    @Test func dominantDisplacementSelectsEitherAxisAndDiscardsLockTravel() {
        for axis in [ScrollAxis.horizontal, .vertical] {
            var harness = Harness()
            harness.engage(axis: nil)
            #expect(harness.session.engine.isEngaged)
            #expect(harness.session.engine.lockedAxis == nil)
            let horizontal = axis == .horizontal
            #expect(harness.move(right: horizontal ? 0.030 : 0.005,
                                 up: horizontal ? 0.005 : 0.030) == nil)
            #expect(harness.session.engine.lockedAxis == axis)
            #expect(harness.sink.movements.isEmpty)

            // A large perpendicular component cannot leak into the output or change the lock.
            harness.move(right: horizontal ? 0.048 : 0.100,
                         up: horizontal ? 0.100 : 0.048)
            #expect(harness.sink.movements == [ScrollMovement(axis: axis, pixels: 24)])
            #expect(harness.session.engine.lockedAxis == axis)
        }
    }

    @Test func diagonalRemainsPendingUntilOneComponentClearlyDominates() {
        var harness = Harness()
        harness.engage(axis: nil)
        for distance in [0.010, 0.030, 0.060] {
            #expect(harness.move(right: distance, up: distance) == nil)
            #expect(harness.session.engine.lockedAxis == nil)
        }
        #expect(harness.move(right: 0.080, up: 0.060) == nil) // Ratio < 1.4.
        #expect(harness.session.engine.lockedAxis == nil)
        #expect(harness.move(right: 0.090, up: 0.060) == nil)
        #expect(harness.session.engine.lockedAxis == .horizontal)
        #expect(harness.sink.movements.isEmpty)
        harness.move(right: 0.108, up: 0.060)
        #expect(harness.sink.movements == [ScrollMovement(axis: .horizontal, pixels: 24)])
    }

    @Test func lockDistanceAndDominanceIncludeTheirThresholds() {
        for axis in [ScrollAxis.horizontal, .vertical] {
            var harness = Harness()
            harness.engage(axis: nil)
            let horizontal = axis == .horizontal
            let distance = GestureConfiguration.prototype.axisLockDistance
            let subordinate = distance / GestureConfiguration.prototype.axisDominanceRatio
            harness.move(right: horizontal ? distance - 0.0001 : 0,
                         up: horizontal ? 0 : distance - 0.0001)
            #expect(harness.session.engine.lockedAxis == nil)
            harness.move(right: horizontal ? distance : subordinate,
                         up: horizontal ? subordinate : distance)
            #expect(harness.session.engine.lockedAxis == axis)
            #expect(harness.sink.movements.isEmpty)
        }
    }

    @Test func slowInitialMovementCanChooseEitherAxisInEitherDirection() {
        for axis in [ScrollAxis.horizontal, .vertical] {
            for direction in [-1.0, 1.0] {
                var harness = Harness()
                harness.engage(axis: nil)
                for index in 1...14 {
                    let distance = direction * Double(index) * 0.001
                    harness.move(right: axis == .horizontal ? distance : 0,
                                 up: axis == .vertical ? distance : 0)
                    #expect(harness.session.engine.lockedAxis == nil)
                }
                let lockDistance = direction * 0.015
                harness.move(right: axis == .horizontal ? lockDistance : 0,
                             up: axis == .vertical ? lockDistance : 0)
                #expect(harness.session.engine.lockedAxis == axis)
                #expect(harness.sink.movements.isEmpty)
                for index in 16...33 {
                    let distance = direction * Double(index) * 0.001
                    harness.move(right: axis == .horizontal ? distance : 0,
                                 up: axis == .vertical ? distance : 0)
                }
                #expect(harness.sink.total == Int(direction * 24))
                #expect(harness.sink.movements.allSatisfy { $0.axis == axis })
            }
        }
    }

    @Test func turningACornerKeepsAxisAndFreshPinchCanSwitchIt() {
        var harness = Harness()
        harness.engage(axis: nil)
        harness.move(right: 0.030, up: 0.005)
        harness.move(right: 0.048, up: 0.005)
        harness.move(right: 0.048, up: 0.200)
        #expect(harness.sink.movements == [ScrollMovement(axis: .horizontal, pixels: 24)])
        harness.move(right: 0.022, up: 0.200)
        #expect(harness.sink.movements == [ScrollMovement(axis: .horizontal, pixels: 24),
                                          ScrollMovement(axis: .horizontal, pixels: -24)])
        harness.move(right: 0.200, up: 0.300, ratio: 0.5)
        #expect(harness.session.engine.lockedAxis == nil)
        #expect(harness.sink.movements.count == 2)
        harness.engage(axis: nil)
        harness.move(up: 0.030)
        #expect(harness.session.engine.lockedAxis == .vertical)
        #expect(harness.sink.movements.count == 2)
        harness.move(up: 0.048)
        #expect(harness.sink.movements.last == ScrollMovement(axis: .vertical, pixels: 24))
    }

    @Test func horizontalReversalAndTwoSecondPauseDoNotRepeatOrLeak() {
        var harness = Harness()
        harness.engage(axis: .horizontal)
        harness.move(right: 0.018)
        harness.move(right: 0.010)
        harness.move(right: 0.002)
        #expect(harness.sink.values == [24])
        harness.move(right: -0.008)
        #expect(harness.sink.values == [24, -24])
        let offsets = [0.003, -0.004, 0.001, -0.003, 0.004]
        for index in 0..<60 {
            harness.move(right: -0.008 + offsets[index % offsets.count],
                         up: Double(index % 4) * 0.030)
        }
        let settledCount = harness.sink.movements.count
        let settledTotal = harness.sink.total
        for index in 0..<60 {
            harness.move(right: -0.008 + offsets[index % offsets.count],
                         up: Double(index % 4) * 0.030)
        }
        #expect(harness.sink.movements.count == settledCount)
        #expect(harness.sink.total == settledTotal)
        #expect(abs(settledTotal) <= 10) // Bounded settling is retained from the spatial filter.
        #expect(harness.sink.movements.allSatisfy { $0.axis == .horizontal })
    }

    @Test func releasePrecedesLargeMovementWhilePendingOrHorizontallyLocked() {
        let axes: [ScrollAxis?] = [nil, .horizontal]
        for axis in axes {
            var harness = Harness()
            harness.engage(axis: axis)
            harness.move(right: 0.300, up: 0.200, ratio: 0.5)
            #expect(harness.sink.movements.isEmpty)
            #expect(harness.session.engine.state == .ready)
            #expect(harness.session.engine.lockedAxis == nil)
            harness.move(right: -0.200, up: -0.200, ratio: 0.5)
            #expect(harness.sink.movements.isEmpty)
        }
    }

    @Test func horizontalTrackingLossRequiresOpenAndFreshPinch() {
        var harness = Harness()
        harness.engage(axis: .horizontal)
        harness.move(right: 0.018)
        harness.frame(confidence: 0.49, horizontalOffset: 0.200)
        #expect(harness.session.engine.state == .waitingForOpen)
        #expect(harness.session.engine.lockedAxis == nil)
        for _ in 0..<8 { harness.move(right: 0.200) }
        #expect(harness.sink.values == [24])
        harness.engage(horizontalOffset: -0.100, axis: nil)
        harness.frame(horizontalOffset: -0.100 + 0.030 * 480 / 640)
        #expect(harness.session.engine.lockedAxis == .horizontal)
        #expect(harness.sink.values == [24])
        harness.frame(horizontalOffset: -0.100 + 0.048 * 480 / 640)
        #expect(harness.sink.values == [24, 24])
    }

    @Test func horizontalFractionAndAxisAreClearedBeforeAVerticalPinch() {
        var harness = Harness()
        harness.engage(axis: .horizontal)
        harness.move(right: 0.0083) // 0.72 pixels retained, without a whole-pixel event.
        #expect(harness.sink.movements.isEmpty)
        harness.move(right: 0.300, ratio: 0.5)
        harness.engage(axis: .vertical)
        harness.move(up: 0.0083)
        #expect(harness.sink.movements.isEmpty)
        harness.move(up: 0.0085)
        #expect(harness.sink.movements == [ScrollMovement(axis: .vertical, pixels: 1)])
    }

    @Test func fingertipMotionCannotChooseAnAxisWhenThePalmIsStill() {
        func fingers(ratio: Double, x: Double, y: Double) -> HandLandmarks {
            HandLandmarks(
                thumbTip: HandPoint(x: x - ratio * 0.2, y: y, confidence: 1),
                indexTip: HandPoint(x: x, y: y, confidence: 1),
                indexMCP: HandPoint(x: 0.4, y: 0.5, confidence: 1),
                littleMCP: HandPoint(x: 0.6, y: 0.5, confidence: 1),
                imageWidth: 640, imageHeight: 480
            )
        }
        var harness = Harness()
        harness.sample(fingers(ratio: 0.5, x: 0.3, y: 0.3))
        harness.sample(fingers(ratio: 0.2, x: 0.4, y: 0.4))
        harness.sample(fingers(ratio: 0.2, x: 0.5, y: 0.5), after: 0.05)
        harness.sample(fingers(ratio: 0.2, x: 0.6, y: 0.6), after: 0.05)
        #expect(harness.session.engine.isEngaged)
        for position in [0.3, 0.7, 0.4, 0.6] {
            harness.sample(fingers(ratio: 0.2, x: position, y: position))
            #expect(harness.session.engine.lockedAxis == nil)
        }
        #expect(harness.sink.movements.isEmpty)
        harness.move(right: 0.030)
        #expect(harness.session.engine.lockedAxis == .horizontal)
        #expect(harness.sink.movements.isEmpty)
        harness.move(right: 0.048)
        #expect(harness.sink.movements == [ScrollMovement(axis: .horizontal, pixels: 24)])
    }

    @Test func interruptionsClearHorizontalLockAndFractionBeforeRearming() {
        enum Interruption: CaseIterable {
            case staleFrame, captureGap, outOfOrderFrame, menu, disable
        }
        for interruption in Interruption.allCases {
            var harness = Harness()
            harness.engage(axis: .horizontal)
            harness.move(right: 0.0083) // A live horizontal lock with a 0.72-pixel remainder.
            #expect(harness.session.engine.lockedAxis == .horizontal)
            #expect(harness.sink.movements.isEmpty)
            let oldGeneration = harness.generation
            switch interruption {
            case .staleFrame:
                let output = harness.session.process(
                    observation: landmarks(horizontalOffset: 0.2),
                    timestamp: harness.time + 0.03, now: harness.time + 0.20,
                    generation: harness.generation
                )
                #expect(output == nil)
                harness.time += 0.20
            case .captureGap:
                #expect(harness.move(right: 0.3, after: 0.151) == nil)
            case .outOfOrderFrame:
                #expect(harness.session.process(
                    observation: landmarks(horizontalOffset: 0.2),
                    timestamp: harness.time - 0.01, now: harness.time,
                    generation: harness.generation
                ) == nil)
            case .menu:
                harness.generation = harness.session.interrupt()
            case .disable:
                harness.session.disable()
                #expect(harness.session.process(
                    observation: landmarks(horizontalOffset: 0.2),
                    timestamp: harness.time + 0.03, now: harness.time + 0.03,
                    generation: oldGeneration
                ) == nil)
                harness.generation = harness.session.enable()
            }
            #expect(harness.session.engine.state == .waitingForOpen)
            #expect(harness.session.engine.lockedAxis == nil)
            if oldGeneration != harness.generation {
                #expect(harness.session.process(
                    observation: landmarks(ratio: 0.5, horizontalOffset: 0.2),
                    timestamp: harness.time + 0.03, now: harness.time + 0.03,
                    generation: oldGeneration
                ) == nil)
            }
            harness.move(right: 0.3)
            #expect(harness.session.engine.state == .waitingForOpen)
            #expect(harness.sink.movements.isEmpty)
            harness.engage(axis: .vertical)
            harness.move(up: 0.0083)
            #expect(harness.sink.movements.isEmpty) // Old horizontal fractions cannot combine with this.
            harness.move(up: 0.0085)
            #expect(harness.sink.movements == [ScrollMovement(axis: .vertical, pixels: 1)])
        }
    }

    @Test func equalImagePixelTravelHasEqualGainAcrossAxesAndAspectRatios() {
        for dimensions in [(640.0, 480.0), (480.0, 640.0), (1920.0, 1080.0)] {
            var totals: [Int] = []
            for axis in [ScrollAxis.horizontal, .vertical] {
                var harness = Harness()
                harness.imageWidth = dimensions.0
                harness.imageHeight = dimensions.1
                harness.engage(axis: nil)
                harness.move(right: axis == .horizontal ? 0.030 : 0,
                             up: axis == .vertical ? 0.030 : 0)
                #expect(harness.session.engine.lockedAxis == axis)
                harness.move(right: axis == .horizontal ? 0.048 : 0,
                             up: axis == .vertical ? 0.048 : 0)
                #expect(harness.sink.movements == [ScrollMovement(axis: axis, pixels: 24)])
                totals.append(harness.sink.total)
            }
            #expect(totals == [24, 24])
        }
    }

    @Test func disableAndInterruptSuppressResultsAlreadyInFlight() {
        var harness = Harness()
        harness.engage()
        let oldGeneration = harness.generation
        harness.session.disable()
        #expect(harness.session.process(observation: landmarks(height: 0.8), timestamp: harness.time + 0.03,
                                        now: harness.time + 0.03, generation: oldGeneration) == nil)
        harness.generation = harness.session.enable()
        #expect(harness.generation != oldGeneration)
        #expect(harness.session.process(observation: landmarks(ratio: 0.5), timestamp: harness.time + 0.04,
                                        now: harness.time + 0.04, generation: oldGeneration) == nil)
        #expect(harness.session.engine.state == .waitingForOpen)
        harness.engage()
        let generationBeforeMenu = harness.generation
        harness.generation = harness.session.interrupt()
        #expect(harness.session.process(observation: landmarks(height: 0.8), timestamp: harness.time + 0.03,
                                        now: harness.time + 0.03, generation: generationBeforeMenu) == nil)
        harness.frame(height: 0.7)
        #expect(harness.session.engine.state == .waitingForOpen)
        #expect(harness.sink.values.isEmpty)
    }
}
