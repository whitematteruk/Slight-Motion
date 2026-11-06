import CoreGraphics
import Testing
@testable import Slight_Motion

struct QuartzScrollSinkTests {
    @Test func documentDirectionMapsToOneQuartzAxis() throws {
        #expect(QuartzScrollSink.quartzDelta(for: 60) == -60)
        #expect(QuartzScrollSink.quartzDelta(for: -60) == 60)
        #expect(QuartzScrollSink.quartzDelta(for: 0) == 0)

        let location = CGPoint(x: 340, y: 220)
        let event = try #require(QuartzScrollSink.makeEvent(pixelsTowardLater: 37, location: location))
        #expect(event.type == .scrollWheel)
        #expect(event.location == location)
        #expect(event.getIntegerValueField(.scrollWheelEventIsContinuous) != 0)
        #expect(event.getIntegerValueField(.scrollWheelEventPointDeltaAxis1) == -37)
        #expect(event.getIntegerValueField(.scrollWheelEventPointDeltaAxis2) == 0)
        #expect(event.getIntegerValueField(.scrollWheelEventDeltaAxis2) == 0)
        #expect(event.getIntegerValueField(.scrollWheelEventDeltaAxis3) == 0)
        #expect(event.getIntegerValueField(.scrollWheelEventScrollPhase) == 0)
        #expect(event.getIntegerValueField(.scrollWheelEventMomentumPhase) == 0)
        #expect(event.flags.isEmpty)
    }

    @Test func reverseDirectionAndZeroDoNotCreateExtraOutput() throws {
        let event = try #require(QuartzScrollSink.makeEvent(pixelsTowardLater: -19, location: .zero))
        #expect(event.getIntegerValueField(.scrollWheelEventPointDeltaAxis1) == 19)
        #expect(QuartzScrollSink.makeEvent(pixelsTowardLater: 0, location: .zero) == nil)
    }

    @Test func adapterBoundsUnexpectedInputsWithoutOverflow() {
        #expect(QuartzScrollSink.quartzDelta(for: Int.max) == -Int32.max)
        #expect(QuartzScrollSink.quartzDelta(for: Int.min) == Int32.max)
    }
}
