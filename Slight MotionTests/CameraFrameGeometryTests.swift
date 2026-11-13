import ImageIO
import Testing
@testable import Slight_Motion

struct CameraFrameGeometryTests {
    @Test func physicalRightAndUpDoNotDependOnOutputMirroring() {
        for mirrored in [false, true] {
            let geometry = CameraFrameGeometry(rawWidth: 640, rawHeight: 480,
                                               orientation: .up, outputIsMirrored: mirrored)
            let start = geometry.physicalPoint(x: 0.5, y: 0.5, confidence: 0.9)
            let end = geometry.physicalPoint(x: mirrored ? 0.6 : 0.4, y: 0.6, confidence: 0.9)
            #expect(abs(end.x - start.x - 0.1) < 1e-9)
            #expect(abs(end.y - start.y - 0.1) < 1e-9)
            #expect(end.confidence == 0.9)
        }
    }

    @Test func orientedDimensionsUseTheVisionTransform() {
        let orientations: [CGImagePropertyOrientation] = [
            .up, .down, .left, .right, .upMirrored, .downMirrored, .leftMirrored, .rightMirrored
        ]
        for orientation in orientations {
            let sideways = [.left, .right, .leftMirrored, .rightMirrored].contains(orientation)
            for outputMirrored in [false, true] {
                let geometry = CameraFrameGeometry(rawWidth: 640, rawHeight: 480,
                                                   orientation: orientation, outputIsMirrored: outputMirrored)
                #expect(geometry.orientation == orientation)
                #expect(geometry.imageWidth == (sideways ? 480 : 640))
                #expect(geometry.imageHeight == (sideways ? 640 : 480))
            }
        }
    }

    @Test func knownPhysicalStrokesSurviveRawMirroringAndEveryEXIFTransform() {
        let orientations: [CGImagePropertyOrientation] = [
            .up, .down, .left, .right, .upMirrored, .downMirrored, .leftMirrored, .rightMirrored
        ]
        // Build the simulated raw camera image, apply its connection mirror,
        // then apply each documented EXIF transform as Vision would. These are
        // geometric operations, independent of the production reflection flags.
        let physicalStroke: [Position] = [(0.35, 0.4), (0.47, 0.4), (0.47, 0.53), (0.31, 0.37)]
        for orientation in orientations {
            for outputMirrored in [false, true] {
                let geometry = CameraFrameGeometry(rawWidth: 640, rawHeight: 480,
                                                   orientation: orientation, outputIsMirrored: outputMirrored)
                for expected in physicalStroke {
                    var raw = rawPosition(forPhysical: expected, orientation: orientation)
                    if outputMirrored { raw.x = 1 - raw.x }
                    let vision = orientedPosition(raw, orientation: orientation)
                    let actual = geometry.physicalPoint(x: vision.x, y: vision.y, confidence: 0.9)
                    #expect(abs(actual.x - expected.x) < 1e-9)
                    #expect(abs(actual.y - expected.y) < 1e-9)
                    #expect(actual.confidence == 0.9)
                }
            }
        }
    }

    @Test func aMirroredRawQuarterTurnRequiresVerticalCorrection() {
        let geometry = CameraFrameGeometry(rawWidth: 640, rawHeight: 480,
                                           orientation: .right, outputIsMirrored: true)
        // After a clockwise Vision rotation, right/up movement in a mirrored
        // raw buffer appears as left/down movement in the upright image.
        let start = geometry.physicalPoint(x: 0.5, y: 0.5, confidence: 1)
        let end = geometry.physicalPoint(x: 0.4, y: 0.4, confidence: 1)
        #expect(abs(end.x - start.x - 0.1) < 1e-9)
        #expect(abs(end.y - start.y - 0.1) < 1e-9)
    }
}

private typealias Position = (x: Double, y: Double)

/// Sensor coordinates before the optional video-output mirror. Start with the
/// unmirrored image of a camera facing the user, then undo the required rotation.
private func rawPosition(forPhysical point: Position, orientation: CGImagePropertyOrientation) -> Position {
    let upright: Position = (1 - point.x, point.y)
    switch orientation {
    case .up, .upMirrored: return upright
    case .down, .downMirrored: return (1 - upright.x, 1 - upright.y)
    case .right, .leftMirrored: return (1 - upright.y, upright.x)
    case .left, .rightMirrored: return (upright.y, 1 - upright.x)
    }
}

/// EXIF's explicit affine transforms, expressed in bottom-left normalized space.
private func orientedPosition(_ point: Position, orientation: CGImagePropertyOrientation) -> Position {
    switch orientation {
    case .up: return point
    case .upMirrored: return (1 - point.x, point.y)
    case .down: return (1 - point.x, 1 - point.y)
    case .downMirrored: return (point.x, 1 - point.y)
    case .leftMirrored: return (1 - point.y, 1 - point.x)
    case .right: return (point.y, 1 - point.x)
    case .rightMirrored: return (point.y, point.x)
    case .left: return (1 - point.y, point.x)
    }
}
