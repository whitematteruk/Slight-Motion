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
    var axisLockDistance = 0.015
    var axisDominanceRatio = 1.4
    var pixelsPerImageHeight = 2_400.0
    // Radius of the tolerated band on either axis (3.84 image pixels at 480px high).
    var positionalDeadband = 0.008
    var maximumPixelsPerUpdate = 60

    static let prototype = GestureConfiguration()
}

struct HandPoint: Sendable {
    let x: Double
    let y: Double
    let confidence: Double
}

struct PalmPosition: Sendable {
    let x: Double
    let y: Double

    func component(on axis: ScrollAxis) -> Double {
        axis == .horizontal ? x : y
    }
}

/// Oriented, normalized landmarks with the user's physical right and up positive.
/// Width and height must describe that same oriented image, including any quarter-turn rotation.
struct HandLandmarks: Sendable {
    let thumbTip: HandPoint
    let indexTip: HandPoint
    let indexMCP: HandPoint
    let littleMCP: HandPoint
    let imageWidth: Double
    let imageHeight: Double

    func measurements(configuration: GestureConfiguration) -> (ratio: Double, palm: PalmPosition)? {
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
        let aspect = imageWidth / imageHeight
        guard palmWidth.isFinite, palmWidth >= configuration.minimumPalmWidthPixels,
              aspect.isFinite else { return nil }
        // Both components use oriented frame height, so intent and gain are
        // independent of image aspect ratio and of which axis is selected.
        let palm = PalmPosition(x: (indexMCP.x + littleMCP.x) / 2 * aspect,
                                y: (indexMCP.y + littleMCP.y) / 2)
        return (pixelDistance(thumbTip, indexTip) / palmWidth, palm)
    }
}

/// A distance recognizer: it produces movement only when a fresh hand position changes.
/// Positive output follows the user's right or up; the event adapter owns Quartz signs.
struct GestureEngine: Sendable {
    enum State: Equatable, Sendable {
        case waitingForOpen
        case ready
        case confirmingPinch
        case scrolling
    }

    let configuration: GestureConfiguration
    private(set) var state: State = .waitingForOpen
    private(set) var lockedAxis: ScrollAxis?
    private var lastTimestamp: TimeInterval?
    private var confirmationStartedAt: TimeInterval?
    private var pinchAnchor: PalmPosition?
    // After locking, the output position stays inside a band on the chosen axis.
    private var acceptedPosition: Double?
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
    ) -> ScrollMovement? {
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
                pinchAnchor = measurement.palm
                lockedAxis = nil
                acceptedPosition = nil
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
            guard let pinchAnchor else {
                cancelInteraction()
                return nil
            }
            guard let axis = lockedAxis else {
                let horizontal = abs(measurement.palm.x - pinchAnchor.x)
                let vertical = abs(measurement.palm.y - pinchAnchor.y)
                let tolerance = 1e-12
                if horizontal + tolerance >= configuration.axisLockDistance,
                   horizontal + tolerance >= configuration.axisDominanceRatio * vertical {
                    lockedAxis = .horizontal
                } else if vertical + tolerance >= configuration.axisLockDistance,
                          vertical + tolerance >= configuration.axisDominanceRatio * horizontal {
                    lockedAxis = .vertical
                }
                if let axis = lockedAxis {
                    acceptedPosition = measurement.palm.component(on: axis)
                }
                // Keep the original anchor while pending. Once locked, discard
                // all intent travel and begin filtering from this exact frame.
                return nil
            }
            guard let anchor = acceptedPosition else {
                cancelInteraction()
                return nil
            }
            let displacement = measurement.palm.component(on: axis) - anchor
            let radius = configuration.positionalDeadband
            guard abs(displacement) > radius + 1e-12 else {
                return nil // Slow motion keeps accumulating against the same output position.
            }
            // Move only the distance beyond the band, avoiding a jump by the full
            // threshold amount. Reversing direction uses twice the radius as slack.
            // After a stroke, small outward movement can still advance to a new
            // extreme; bounded jitter within the band cannot cause repeated reversals.
            let acceptedDisplacement = displacement - (displacement > 0 ? radius : -radius)
            acceptedPosition = anchor + acceptedDisplacement
            let pixels = acceptedDisplacement * configuration.pixelsPerImageHeight + fractionalPixels
            let cap = configuration.maximumPixelsPerUpdate
            if abs(pixels) >= Double(cap) {
                fractionalPixels = 0 // Capped excess must never replay after the hand stops.
                return ScrollMovement(axis: axis, pixels: pixels > 0 ? cap : -cap)
            }
            // Avoid losing a whole unit to floating-point noise at an integer boundary.
            let roundingTolerance = pixels < 0 ? -1e-9 : 1e-9
            let wholePixels = Int((pixels + roundingTolerance).rounded(.towardZero))
            fractionalPixels = pixels - Double(wholePixels)
            return wholePixels == 0 ? nil : ScrollMovement(axis: axis, pixels: wholePixels)
        }
        return nil
    }

    private mutating func clearMovement() {
        confirmationStartedAt = nil
        pinchAnchor = nil
        lockedAxis = nil
        acceptedPosition = nil
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
    ) -> ScrollMovement? {
        guard isEnabled, generation == resultGeneration else { return nil }
        return engine.process(observation: observation, timestamp: timestamp, now: now)
    }
}
