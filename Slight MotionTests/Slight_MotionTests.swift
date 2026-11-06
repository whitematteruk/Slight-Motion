import Foundation
import Testing
@testable import Slight_Motion

private struct RecordingScrollSink {
    var values: [Int] = []
    mutating func receive(_ value: Int?) {
        if let value { values.append(value) }
    }
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
    ) -> Int? {
        time += interval
        let output = session.process(
            observation: landmarks(ratio: ratio, height: height, confidence: confidence, horizontalOffset: horizontalOffset),
            timestamp: time, now: time, generation: generation
        )
        sink.receive(output)
        return output
    }

    mutating func engage(at height: Double = 0.5) {
        frame(ratio: 0.5, height: height)
        frame(height: height)
        frame(height: height, after: 0.05)
        frame(height: height, after: 0.05)
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
        harness.frame(height: 0.518)
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
        #expect(abs((measured?.height ?? -1) - 0.4) < 1e-9)
        let tinyHand = landmarks(width: 20)
        #expect(tinyHand.measurements(configuration: .prototype) == nil)
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
