import AVFoundation
import CoreMedia
import ImageIO
import Vision

enum CameraState: Sendable {
    case starting
    case running
    case failed(String)
}

/// Session configuration, Vision work and capture callbacks share one serial queue.
/// Only the small, immutable landmark result ever leaves that queue.
final class HandCamera: NSObject, @unchecked Sendable {
    typealias SampleHandler = @MainActor @Sendable (UInt64, HandLandmarks?, TimeInterval) -> Void
    typealias StateHandler = @MainActor @Sendable (UInt64, CameraState) -> Void

    private let queue = DispatchQueue(label: "uk.whitematter.Slight-Motion.camera", qos: .userInitiated)
    private let gate = NSLock()
    private var allowedGeneration: UInt64?
    private let onSample: SampleHandler
    private let onState: StateHandler

    // Confined to queue.
    private var session: AVCaptureSession?
    private var output: AVCaptureVideoDataOutput?
    private var sessionGeneration: UInt64?
    private var notificationTokens: [NSObjectProtocol] = []
    private var rotationCoordinator: AVCaptureDevice.RotationCoordinator?
    private var rotationObservation: NSKeyValueObservation?
    private var fallbackOrientation: CGImagePropertyOrientation = .up
    private let request: VNDetectHumanHandPoseRequest = {
        let request = VNDetectHumanHandPoseRequest()
        // Detect a second hand so ambiguity is treated as tracking loss.
        request.maximumHandCount = 2
        return request
    }()

    init(onSample: @escaping SampleHandler, onState: @escaping StateHandler) {
        self.onSample = onSample
        self.onState = onState
        super.init()
    }

    func start(generation: UInt64) {
        gate.lock()
        allowedGeneration = generation
        gate.unlock()
        queue.async { [weak self] in
            guard let self else { return }
            self.tearDown()
            guard self.isAllowed(generation) else { return }
            self.deliver(.starting, generation: generation)
            self.configureAndStart(generation: generation)
        }
    }

    /// Invalidates delivery immediately, including Vision work already in flight.
    func stop() {
        gate.lock()
        allowedGeneration = nil
        gate.unlock()
        queue.async { [weak self] in self?.tearDown() }
    }

    private func isAllowed(_ generation: UInt64) -> Bool {
        gate.lock()
        defer { gate.unlock() }
        return allowedGeneration == generation
    }

    private func configureAndStart(generation: UInt64) {
        guard AVCaptureDevice.authorizationStatus(for: .video) == .authorized else {
            deliver(.failed("Camera access is required. Check permissions, then retry."), generation: generation)
            return
        }
        guard let device = AVCaptureDevice.default(for: .video) else {
            deliver(.failed("No camera is available. Connect a camera, then retry."), generation: generation)
            return
        }

        let capture = AVCaptureSession()
        let videoOutput = AVCaptureVideoDataOutput()
        do {
            let input = try AVCaptureDeviceInput(device: device)
            capture.beginConfiguration()
            if capture.canSetSessionPreset(.vga640x480) {
                capture.sessionPreset = .vga640x480
            } else {
                capture.sessionPreset = .medium
            }
            guard capture.canAddInput(input) else {
                capture.commitConfiguration()
                deliver(.failed("The camera could not be opened. Close other camera apps and retry."), generation: generation)
                return
            }
            capture.addInput(input)
            videoOutput.alwaysDiscardsLateVideoFrames = true
            videoOutput.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
            ]
            guard capture.canAddOutput(videoOutput) else {
                capture.commitConfiguration()
                deliver(.failed("This camera cannot provide video frames. Try another camera and retry."), generation: generation)
                return
            }
            capture.addOutput(videoOutput)
            videoOutput.setSampleBufferDelegate(self, queue: queue)

            let coordinator = AVCaptureDevice.RotationCoordinator(device: device, previewLayer: nil)
            let angle = coordinator.videoRotationAngleForHorizonLevelCapture
            let quarterTurn = (Int((angle / 90).rounded()) % 4 + 4) % 4
            let uprightAngle = CGFloat(quarterTurn * 90)
            fallbackOrientation = [.up, .right, .down, .left][quarterTurn]
            if let connection = videoOutput.connection(with: .video) {
                if connection.isVideoMirroringSupported {
                    connection.automaticallyAdjustsVideoMirroring = false
                    connection.isVideoMirrored = false
                }
                // VideoDataOutput physically rotates its buffers, so Vision then sees .up.
                if connection.isVideoRotationAngleSupported(uprightAngle) {
                    connection.videoRotationAngle = uprightAngle
                    fallbackOrientation = .up
                } else if connection.isVideoRotationAngleSupported(0) {
                    connection.videoRotationAngle = 0
                }
            }
            capture.commitConfiguration()

            // A preset can change activeFormat; set frame duration after committing it.
            if device.activeFormat.videoSupportedFrameRateRanges.contains(where: {
                $0.minFrameRate <= 30 && $0.maxFrameRate >= 30
            }) {
                try device.lockForConfiguration()
                device.activeVideoMinFrameDuration = CMTime(value: 1, timescale: 30)
                device.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: 30)
                device.unlockForConfiguration()
            }

            guard isAllowed(generation) else {
                videoOutput.setSampleBufferDelegate(nil, queue: nil)
                return
            }
            session = capture
            output = videoOutput
            sessionGeneration = generation
            rotationCoordinator = coordinator
            // Rather than mix differently oriented frames within a gesture, stop and
            // require Retry if a Continuity Camera changes its physical orientation.
            rotationObservation = coordinator.observe(\.videoRotationAngleForHorizonLevelCapture, options: [.new]) { [weak self] _, change in
                guard let newAngle = change.newValue, abs(newAngle - angle) > 1 else { return }
                self?.queue.async { [weak self] in
                    self?.fail("Camera orientation changed. Retry to recalibrate.", generation: generation)
                }
            }
            observeFailures(of: capture, device: device, generation: generation)
            capture.startRunning()
            guard isAllowed(generation) else {
                tearDown()
                return
            }
            if capture.isRunning {
                deliver(.running, generation: generation)
            } else {
                fail("The camera did not start. Close other camera apps and retry.", generation: generation)
            }
        } catch {
            tearDown()
            deliver(.failed("The camera could not start. Check its connection and retry."), generation: generation)
        }
    }

    private func observeFailures(of capture: AVCaptureSession, device: AVCaptureDevice, generation: UInt64) {
        let center = NotificationCenter.default
        notificationTokens.append(center.addObserver(forName: AVCaptureSession.runtimeErrorNotification, object: capture, queue: nil) { [weak self] _ in
            self?.queue.async { [weak self] in
                self?.fail("The camera stopped unexpectedly. Retry to reconnect.", generation: generation)
            }
        })
        notificationTokens.append(center.addObserver(forName: AVCaptureSession.wasInterruptedNotification, object: capture, queue: nil) { [weak self] _ in
            self?.queue.async { [weak self] in
                self?.fail("Camera capture was interrupted. Retry when the camera is available.", generation: generation)
            }
        })
        notificationTokens.append(center.addObserver(forName: AVCaptureDevice.wasDisconnectedNotification, object: device, queue: nil) { [weak self] _ in
            self?.queue.async { [weak self] in
                self?.fail("The camera was disconnected. Reconnect it, then retry.", generation: generation)
            }
        })
    }

    private func fail(_ message: String, generation: UInt64) {
        guard sessionGeneration == generation, isAllowed(generation) else { return }
        tearDown()
        deliver(.failed(message), generation: generation)
    }

    private func tearDown() {
        rotationObservation?.invalidate()
        rotationObservation = nil
        rotationCoordinator = nil
        notificationTokens.forEach { NotificationCenter.default.removeObserver($0) }
        notificationTokens.removeAll()
        output?.setSampleBufferDelegate(nil, queue: nil)
        if let session {
            if session.isRunning { session.stopRunning() }
            session.beginConfiguration()
            session.outputs.forEach { session.removeOutput($0) }
            session.inputs.forEach { session.removeInput($0) }
            session.commitConfiguration()
        }
        output = nil
        session = nil
        sessionGeneration = nil
        fallbackOrientation = .up
    }

    private func deliver(_ state: CameraState, generation: UInt64) {
        Task { @MainActor [weak self] in
            guard let self, self.isAllowed(generation) else { return }
            self.onState(generation, state)
        }
    }

    private func deliver(_ landmarks: HandLandmarks?, timestamp: TimeInterval, generation: UInt64) {
        Task { @MainActor [weak self] in
            guard let self, self.isAllowed(generation) else { return }
            self.onSample(generation, landmarks, timestamp)
        }
    }
}

extension HandCamera: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard output === self.output,
              let generation = sessionGeneration, isAllowed(generation), let session,
              let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        let hostTime: CMTime
        if let clock = session.synchronizationClock {
            hostTime = CMSyncConvertTime(presentationTime, from: clock, to: CMClockGetHostTimeClock())
        } else {
            // Reject a frame whose timebase cannot be established; do not invent a
            // capture timestamp that would make an old frame appear fresh.
            deliver(nil, timestamp: CMClockGetTime(CMClockGetHostTimeClock()).seconds, generation: generation)
            return
        }
        let timestamp = hostTime.seconds
        let now = CMClockGetTime(CMClockGetHostTimeClock()).seconds
        guard timestamp.isFinite,
              now - timestamp <= GestureConfiguration.prototype.maximumObservationAge,
              timestamp <= now + 0.010 else {
            deliver(nil, timestamp: now, generation: generation)
            return
        }

        // Honor explicit orientation metadata if the camera supplies it. Otherwise
        // use the known VideoDataOutput rotation configured above.
        let metadata = CMGetAttachment(sampleBuffer, key: kCGImagePropertyOrientation, attachmentModeOut: nil) as? NSNumber
        let orientation = metadata.flatMap { CGImagePropertyOrientation(rawValue: $0.uint32Value) } ?? fallbackOrientation
        let geometry = CameraFrameGeometry(
            rawWidth: Double(CVPixelBufferGetWidth(pixelBuffer)),
            rawHeight: Double(CVPixelBufferGetHeight(pixelBuffer)),
            orientation: orientation,
            outputIsMirrored: connection.isVideoMirrored
        )

        do {
            let handler = VNImageRequestHandler(cmSampleBuffer: sampleBuffer, orientation: geometry.orientation, options: [:])
            try handler.perform([request])
            guard isAllowed(generation), let hands = request.results, hands.count == 1,
                  let hand = hands.first else {
                deliver(nil, timestamp: timestamp, generation: generation)
                return
            }
            let points = try hand.recognizedPoints(.all)
            func point(_ name: VNHumanHandPoseObservation.JointName) -> HandPoint? {
                guard let point = points[name] else { return nil }
                return geometry.physicalPoint(x: point.location.x, y: point.location.y,
                                              confidence: Double(point.confidence))
            }
            guard let thumb = point(.thumbTip), let index = point(.indexTip),
                  let indexMCP = point(.indexMCP), let littleMCP = point(.littleMCP) else {
                deliver(nil, timestamp: timestamp, generation: generation)
                return
            }
            let landmarks = HandLandmarks(thumbTip: thumb, indexTip: index, indexMCP: indexMCP,
                                          littleMCP: littleMCP, imageWidth: geometry.imageWidth,
                                          imageHeight: geometry.imageHeight)
            deliver(landmarks, timestamp: timestamp, generation: generation)
        } catch {
            deliver(nil, timestamp: timestamp, generation: generation)
        }
    }
}
