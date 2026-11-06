import CoreGraphics

/// Converts the recogniser's document direction to one ordinary Quartz wheel event.
/// This adapter never activates an app, moves the pointer, or schedules more output.
@MainActor
struct QuartzScrollSink {
    @discardableResult
    func post(pixelsTowardLater pixels: Int) -> Bool {
        guard pixels != 0, CGPreflightPostEventAccess(),
              let pointer = CGEvent(source: nil)?.location,
              let event = Self.makeEvent(pixelsTowardLater: pixels, location: pointer) else {
            return false
        }
        event.post(tap: .cgSessionEventTap)
        return true
    }

    /// Positive model displacement means move content up to reveal later material.
    /// Quartz's vertical wheel delta is negative for that direction. Keep this sign
    /// conversion here so Safari/Preview direction checks have exactly one adapter.
    nonisolated static func quartzDelta(for pixelsTowardLater: Int) -> Int32 {
        let bounded = min(max(pixelsTowardLater, -Int(Int32.max)), Int(Int32.max))
        return -Int32(bounded)
    }

    /// Separated from posting so unit tests can inspect real CGEvents without
    /// sending input or requiring Accessibility access.
    nonisolated static func makeEvent(pixelsTowardLater pixels: Int, location: CGPoint) -> CGEvent? {
        guard pixels != 0,
              let event = CGEvent(
                scrollWheelEvent2Source: nil,
                units: .pixel,
                wheelCount: 1,
                wheel1: quartzDelta(for: pixels),
                wheel2: 0,
                wheel3: 0
              ) else { return nil }
        event.location = location
        event.flags = []
        event.setIntegerValueField(.scrollWheelEventScrollPhase, value: 0)
        event.setIntegerValueField(.scrollWheelEventMomentumPhase, value: 0)
        return event
    }
}
