import ImageIO

/// Describes the exact buffer/orientation pair passed to Vision, independently of
/// any preview. Landmarks leave this boundary with the user's right and up positive.
struct CameraFrameGeometry: Sendable {
    let orientation: CGImagePropertyOrientation
    let imageWidth: Double
    let imageHeight: Double
    private let reverseVisionX: Bool
    private let reverseVisionY: Bool

    init(rawWidth: Double, rawHeight: Double, orientation: CGImagePropertyOrientation,
         outputIsMirrored: Bool) {
        self.orientation = orientation
        let sideways = [.left, .leftMirrored, .right, .rightMirrored].contains(orientation)
        imageWidth = sideways ? rawHeight : rawWidth
        imageHeight = sideways ? rawWidth : rawHeight
        let orientationReflects = [.upMirrored, .downMirrored, .leftMirrored, .rightMirrored].contains(orientation)
        // VideoDataOutput mirrors about the buffer's vertical axis. A remaining
        // quarter-turn in Vision rotates that reflection into a vertical flip.
        // Mirrored EXIF orientations add a horizontal flip after their rotation
        // (leftMirrored uses clockwise rotation, rightMirrored counterclockwise).
        let horizontalReflection = orientationReflects != (outputIsMirrored && !sideways)
        reverseVisionX = !horizontalReflection
        reverseVisionY = outputIsMirrored && sideways
    }

    func physicalPoint(x: Double, y: Double, confidence: Double) -> HandPoint {
        // An upright, unmirrored camera facing the user sees physical right as
        // decreasing image X. Either hand uses this same image-space conversion.
        HandPoint(x: reverseVisionX ? 1 - x : x,
                  y: reverseVisionY ? 1 - y : y,
                  confidence: confidence)
    }
}
