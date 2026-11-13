import CoreGraphics

/// Converts the recogniser's document direction to one ordinary Quartz wheel event.
/// This adapter never activates an app, moves the pointer, or schedules more output.
@MainActor
struct QuartzScrollSink {
    @discardableResult
    func post(_ movement: ScrollMovement) -> Bool {
        guard movement.pixels != 0, CGPreflightPostEventAccess(),
              let pointer = CGEvent(source: nil)?.location,
              let event = Self.makeEvent(movement: movement, location: pointer) else {
            return false
        }
        event.post(tap: .cgSessionEventTap)
        return true
    }

    /// Quartz signs live only at the event boundary: content right is positive
    /// wheel2, while content up (later text) is negative wheel1.
    nonisolated static func quartzDelta(for pixels: Int, axis: ScrollAxis = .vertical) -> Int32 {
        let bounded = Int32(min(max(pixels, -Int(Int32.max)), Int(Int32.max)))
        return axis == .vertical ? -bounded : bounded
    }

    /// Separated from posting so unit tests can inspect real CGEvents without
    /// sending input or requiring Accessibility access.
    nonisolated static func makeEvent(movement: ScrollMovement, location: CGPoint) -> CGEvent? {
        let delta = quartzDelta(for: movement.pixels, axis: movement.axis)
        guard movement.pixels != 0,
              let event = CGEvent(
                scrollWheelEvent2Source: nil,
                units: .pixel,
                wheelCount: movement.axis == .horizontal ? 2 : 1,
                wheel1: movement.axis == .vertical ? delta : 0,
                wheel2: movement.axis == .horizontal ? delta : 0,
                wheel3: 0
              ) else { return nil }
        event.location = location
        event.flags = []
        event.setIntegerValueField(.scrollWheelEventScrollPhase, value: 0)
        event.setIntegerValueField(.scrollWheelEventMomentumPhase, value: 0)
        return event
    }
}
