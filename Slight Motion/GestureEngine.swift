import Foundation

/// All prototype tuning lives here. Distances and heights use the oriented camera image.
struct GestureConfiguration: Sendable {
    var minimumConfidence = 0.5
    var closeRatio = 0.25
    var openRatio = 0.40
    var confirmationDuration: TimeInterval = 0.100
    var maximumCaptureGap: TimeInterval = 0.150
    var maximumObservationAge: TimeInterval = 0.150
    var minimumPalmWidthPixels = 12.0
    var pixelsPerImageHeight = 2_400.0
    // Radius of the tolerated height band (3.84 image pixels at 480px high).
    var positionalDeadband = 0.008
    var maximumPixelsPerUpdate = 60

    static let prototype = GestureConfiguration()
}

struct HandPoint: Sendable {
    let x: Double
    let y: Double
    let confidence: Double
}

/// Vision landmarks in the oriented image's normalized coordinate system, with up positive.
/// Width and height must describe that same oriented image, including any quarter-turn rotation.
struct HandLandmarks: Sendable {
    let thumbTip: HandPoint
    let indexTip: HandPoint
    let indexMCP: HandPoint
    let littleMCP: HandPoint
    let imageWidth: Double
    let imageHeight: Double

    func measurements(configuration: GestureConfiguration) -> (ratio: Double, height: Double)? {
        guard imageWidth.isFinite, imageHeight.isFinite, imageWidth > 0, imageHeight > 0 else {
            return nil
        }
        let points = [thumbTip, indexTip, indexMCP, littleMCP]
        guard points.allSatisfy({ point in
            point.confidence.isFinite && point.confidence >= configuration.minimumConfidence &&
                point.x.isFinite && point.y.isFinite &&
                (0...1).contains(point.x) && (0...1).contains(point.y)
        }) else { return nil }

        func pixelDistance(_ first: HandPoint, _ second: HandPoint) -> Double {
            hypot((first.x - second.x) * imageWidth, (first.y - second.y) * imageHeight)
        }
        let palmWidth = pixelDistance(indexMCP, littleMCP)
        guard palmWidth >= configuration.minimumPalmWidthPixels else { return nil }
        return (pixelDistance(thumbTip, indexTip) / palmWidth, (indexMCP.y + littleMCP.y) / 2)
    }
}

/// A distance recognizer: it produces movement only when a fresh hand position changes.
/// Positive output means reveal later material; the event adapter owns the Quartz sign.
struct GestureEngine: Sendable {
    enum State: Equatable, Sendable {
        case waitingForOpen
        case ready
        case confirmingPinch
        case scrolling
    }

    let configuration: GestureConfiguration
    private(set) var state: State = .waitingForOpen
    private var lastTimestamp: TimeInterval?
    private var confirmationStartedAt: TimeInterval?
    // The output position stays inside a band around the observed hand height.
    private var acceptedHeight: Double?
    private var fractionalPixels = 0.0

    var isEngaged: Bool { state == .scrolling }

    init(configuration: GestureConfiguration = .prototype) {
        self.configuration = configuration
    }

    mutating func reset() {
        cancelInteraction()
        lastTimestamp = nil
    }

    /// `timestamp` and `now` use the same monotonic capture clock, in seconds.
    mutating func process(
        observation: HandLandmarks?,
        timestamp: TimeInterval,
        now: TimeInterval
    ) -> Int? {
        guard timestamp.isFinite, now.isFinite,
              timestamp <= now + 0.010,
              now - timestamp <= configuration.maximumObservationAge else {
            cancelInteraction()
            return nil
        }
        if let previous = lastTimestamp {
            guard timestamp > previous else {
                // Never let an old observation move the anchor or re-arm the recognizer.
                cancelInteraction()
                return nil
            }
            if timestamp - previous > configuration.maximumCaptureGap {
                cancelInteraction()
            }
        }
        lastTimestamp = timestamp
        guard let measurement = observation?.measurements(configuration: configuration) else {
            cancelInteraction()
            return nil
        }

        switch state {
        case .waitingForOpen:
            if measurement.ratio >= configuration.openRatio {
                state = .ready
            }
        case .ready:
            if measurement.ratio <= configuration.closeRatio {
                confirmationStartedAt = timestamp
                state = .confirmingPinch
            }
        case .confirmingPinch:
            guard measurement.ratio <= configuration.closeRatio else {
                confirmationStartedAt = nil
                state = .ready
                return nil
            }
            if let started = confirmationStartedAt,
               timestamp - started + 1e-9 >= configuration.confirmationDuration {
                state = .scrolling
                acceptedHeight = measurement.height
                fractionalPixels = 0
                confirmationStartedAt = nil
                // Closing the fingertips, and motion during confirmation, never scrolls.
            }
        case .scrolling:
            if measurement.ratio >= configuration.openRatio {
                clearMovement()
                state = .ready
                return nil // Discard movement from the release frame.
            }
            guard let anchor = acceptedHeight else {
                cancelInteraction()
                return nil
            }
            let displacement = measurement.height - anchor
            let radius = configuration.positionalDeadband
            guard abs(displacement) > radius + 1e-12 else {
                return nil // Slow motion keeps accumulating against the same output position.
            }
            // Move only the distance beyond the band, avoiding a jump by the full
            // threshold amount. Reversing direction uses twice the radius as slack.
            // After a stroke, small outward movement can still advance to a new
            // extreme; bounded jitter within the band cannot cause repeated reversals.
            let acceptedDisplacement = displacement - (displacement > 0 ? radius : -radius)
            acceptedHeight = anchor + acceptedDisplacement
            let pixels = acceptedDisplacement * configuration.pixelsPerImageHeight + fractionalPixels
            let cap = configuration.maximumPixelsPerUpdate
            if abs(pixels) >= Double(cap) {
                fractionalPixels = 0 // Capped excess must never replay after the hand stops.
                return pixels > 0 ? cap : -cap
            }
            // Avoid losing a whole unit to floating-point noise at an integer boundary.
            let roundingTolerance = pixels < 0 ? -1e-9 : 1e-9
            let wholePixels = Int((pixels + roundingTolerance).rounded(.towardZero))
            fractionalPixels = pixels - Double(wholePixels)
            return wholePixels == 0 ? nil : wholePixels
        }
        return nil
    }

    private mutating func clearMovement() {
        confirmationStartedAt = nil
        acceptedHeight = nil
        fractionalPixels = 0
    }

    private mutating func cancelInteraction() {
        clearMovement()
        state = .waitingForOpen
    }
}

/// Lifecycle gate used by the live controller and deterministic tests. A capture result
/// belongs to one generation and cannot become output after disable, retry or a menu interruption.
struct GestureSession: Sendable {
    private(set) var engine: GestureEngine
    private(set) var generation: UInt64 = 0
    private(set) var isEnabled = false

    init(configuration: GestureConfiguration = .prototype) {
        engine = GestureEngine(configuration: configuration)
    }

    @discardableResult
    mutating func enable() -> UInt64 {
        isEnabled = true
        return interrupt()
    }

    mutating func disable() {
        isEnabled = false
        interrupt()
    }

    @discardableResult
    mutating func interrupt() -> UInt64 {
        generation &+= 1
        engine.reset()
        return generation
    }

    mutating func process(
        observation: HandLandmarks?,
        timestamp: TimeInterval,
        now: TimeInterval,
        generation resultGeneration: UInt64
    ) -> Int? {
        guard isEnabled, generation == resultGeneration else { return nil }
        return engine.process(observation: observation, timestamp: timestamp, now: now)
    }
}
