import AppKit
import AVFoundation
import Combine
import CoreMedia
import CoreGraphics

@MainActor
final class MotionController: ObservableObject {
    enum CameraPermission { case notRequested, granted, denied, restricted }

    @Published private(set) var isEnabled = false
    @Published private(set) var isEngaged = false
    @Published private(set) var cameraPermission: CameraPermission = .notRequested
    @Published private(set) var accessibilityGranted = false
    @Published private(set) var isStarting = false
    @Published private(set) var isCapturing = false
    @Published private(set) var statusTitle = "Off"
    @Published private(set) var statusDetail = "Enable when you’re ready to read."
    @Published private(set) var cameraError: String?
    @Published private(set) var debugResult: String?

    let diagnosticsEnabled = ProcessInfo.processInfo.arguments.contains("--scroll-diagnostics")
    private var gesture = GestureSession()
    private let sink = QuartzScrollSink()
    private var captureGeneration: UInt64 = 0
    private var permissionAttempt: UInt64 = 0
    private var pulseGeneration: UInt64 = 0
    private var menuIsOpen = false
    private var systemSuspended = false
    private var acceptSamplesAfter: TimeInterval = 0
    private var lastFrameAt: TimeInterval?
    private var captureStartedAt: TimeInterval?
    private var lastPermissionCheck: TimeInterval = 0
    private var pendingPulse: ScrollMovement?
    private var pulseTask: Task<Void, Never>?
    private var timer: Timer?
    private var observers: [NSObjectProtocol] = []

    private lazy var camera = HandCamera(
        onSample: { [weak self] generation, observation, timestamp in
            self?.receive(observation, timestamp: timestamp, generation: generation)
        },
        onState: { [weak self] generation, state in
            self?.cameraStateChanged(state, generation: generation)
        }
    )

    init() {
        refreshPermissions()
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.recheckAndResume() }
        })
        observers.append(center.addObserver(forName: NSApplication.willTerminateNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.disable() }
        })
        let workspace = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.willSleepNotification, NSWorkspace.screensDidSleepNotification, NSWorkspace.sessionDidResignActiveNotification] {
            observers.append(workspace.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.suspendForSystem() }
            })
        }
        for name in [NSWorkspace.didWakeNotification, NSWorkspace.screensDidWakeNotification, NSWorkspace.sessionDidBecomeActiveNotification] {
            observers.append(workspace.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in
                    self?.systemSuspended = false
                    self?.recheckAndResume()
                }
            })
        }
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    var needsPermissions: Bool { cameraPermission != .granted || !accessibilityGranted }
    var cameraPermissionLabel: String {
        switch cameraPermission {
        case .notRequested: "Not requested"
        case .granted: "Allowed"
        case .denied: "Allow in Settings"
        case .restricted: "Restricted by this Mac"
        }
    }

    func toggleEnabled() {
        if isEnabled { disable() } else { enable() }
    }

    func enable() {
        guard !isEnabled else { return }
        isEnabled = true
        _ = gesture.enable()
        resetRecognition()
        requestPermissions()
    }

    func disable() {
        isEnabled = false
        permissionAttempt &+= 1
        gesture.disable()
        stopCamera()
        cancelPulse()
        isEngaged = false
        cameraError = nil
        updateStatus()
    }

    /// Both permission requests originate in an explicit menu action.
    func requestPermissions() {
        permissionAttempt &+= 1
        let attempt = permissionAttempt
        Task { [weak self] in
            guard let self else { return }
            if AVCaptureDevice.authorizationStatus(for: .video) == .notDetermined {
                _ = await AVCaptureDevice.requestAccess(for: .video)
            }
            guard attempt == self.permissionAttempt else { return }
            if !CGPreflightPostEventAccess() { _ = CGRequestPostEventAccess() }
            self.refreshPermissions()
            self.startIfPermitted()
            self.updateStatus()
        }
        updateStatus()
    }

    func retryCamera() {
        cameraError = nil
        stopCamera()
        resetRecognition()
        refreshPermissions()
        startIfPermitted()
        updateStatus()
    }

    func openSettings(camera: Bool) {
        let pane = camera ? "Privacy_Camera" : "Privacy_Accessibility"
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)") {
            NSWorkspace.shared.open(url)
        }
    }

    func menuVisibilityChanged(_ visible: Bool) {
        guard visible != menuIsOpen else { return }
        menuIsOpen = visible
        resetRecognition()
        if visible {
            cancelPulse()
            recheckAndResume()
        } else if let movement = pendingPulse {
            pendingPulse = nil
            deliverPulseAfterDelay(movement)
        }
        updateStatus()
    }

    func queueDiagnosticPulse(_ movement: ScrollMovement) {
        guard diagnosticsEnabled, !isEnabled else { return }
        cancelPulse()
        if !CGPreflightPostEventAccess() {
            _ = CGRequestPostEventAccess()
            refreshPermissions()
            guard accessibilityGranted else {
                debugResult = "Allow Slight Motion in Accessibility settings, then retry this test."
                return
            }
        }
        pendingPulse = movement
        debugResult = "Close this panel. Pulse follows in 3 seconds."
    }

    func quit() {
        disable()
        NSApp.terminate(nil)
    }

    private static var now: TimeInterval { CMClockGetTime(CMClockGetHostTimeClock()).seconds }

    private func refreshPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: cameraPermission = .granted
        case .denied: cameraPermission = .denied
        case .restricted: cameraPermission = .restricted
        case .notDetermined: cameraPermission = .notRequested
        @unknown default: cameraPermission = .denied
        }
        accessibilityGranted = CGPreflightPostEventAccess()
    }

    private func recheckAndResume() {
        refreshPermissions()
        if needsPermissions, isCapturing || isStarting {
            stopCamera()
            resetRecognition()
        }
        startIfPermitted()
        updateStatus()
    }

    private func startIfPermitted() {
        guard isEnabled, !needsPermissions, !systemSuspended, cameraError == nil,
              !isCapturing, !isStarting else { return }
        captureGeneration &+= 1
        isStarting = true
        captureStartedAt = Self.now
        lastFrameAt = nil
        resetRecognition()
        camera.start(generation: captureGeneration)
    }

    private func stopCamera() {
        captureGeneration &+= 1
        camera.stop()
        isCapturing = false
        isStarting = false
        lastFrameAt = nil
        captureStartedAt = nil
    }

    private func resetRecognition() {
        _ = gesture.interrupt()
        acceptSamplesAfter = Self.now
        isEngaged = false
    }

    private func suspendForSystem() {
        systemSuspended = true
        stopCamera()
        resetRecognition()
        cancelPulse()
        updateStatus()
    }

    private func cameraStateChanged(_ state: CameraState, generation: UInt64) {
        guard generation == captureGeneration, isEnabled else { return }
        switch state {
        case .starting: isStarting = true
        case .running:
            isStarting = false
            isCapturing = true
        case .failed(let message):
            cameraError = message
            stopCamera()
            resetRecognition()
        }
        updateStatus()
    }

    private func receive(_ observation: HandLandmarks?, timestamp: TimeInterval, generation: UInt64) {
        guard generation == captureGeneration, isEnabled, isCapturing else { return }
        let now = Self.now
        lastFrameAt = timestamp
        guard !menuIsOpen, !systemSuspended, timestamp >= acceptSamplesAfter else { return }
        if let movement = gesture.process(observation: observation, timestamp: timestamp, now: now, generation: gesture.generation) {
            if !sink.post(movement) {
                refreshPermissions()
                stopCamera()
                resetRecognition()
                cameraError = accessibilityGranted ? "Couldn’t create a scroll event. Please retry." : nil
            }
        }
        isEngaged = gesture.engine.isEngaged
        updateStatus()
    }

    private func tick() {
        let now = Self.now
        if now - lastPermissionCheck > 1 {
            lastPermissionCheck = now
            if isEnabled || menuIsOpen { recheckAndResume() }
        }
        guard isEnabled, isCapturing || isStarting else { return }
        if let lastFrameAt, now - lastFrameAt > GestureConfiguration.prototype.maximumCaptureGap {
            if isEngaged || gesture.engine.state != .waitingForOpen { resetRecognition(); updateStatus() }
        }
        if now - (lastFrameAt ?? captureStartedAt ?? now) > 4 {
            cameraError = "The camera stopped delivering frames. Check the connection and retry."
            stopCamera()
            resetRecognition()
            updateStatus()
        }
    }

    private func updateStatus() {
        if !isEnabled {
            statusTitle = "Off"
            statusDetail = "Enable when you’re ready to read."
        } else if needsPermissions {
            statusTitle = "Permissions needed"
            if cameraPermission == .granted && !accessibilityGranted {
                statusDetail = "Allow Accessibility in Settings. If it’s already on, quit and reopen Slight Motion."
            } else if accessibilityGranted {
                statusDetail = "Allow Camera in Settings, then check permissions again."
            } else {
                statusDetail = "Allow Camera and Accessibility to get started."
            }
        } else if let cameraError {
            statusTitle = "Camera unavailable"
            statusDetail = cameraError
        } else if systemSuspended {
            statusTitle = "Paused"
            statusDetail = "Scrolling resumes after this Mac wakes. Open your fingers first."
        } else if isStarting {
            statusTitle = "Starting camera…"
            statusDetail = "Get comfortable and bring one hand into view."
        } else if menuIsOpen {
            statusTitle = "Paused while menu is open"
            statusDetail = "Close this panel, open your fingers, then pinch to scroll."
        } else {
            switch gesture.engine.state {
            case .waitingForOpen:
                statusTitle = "Looking for an open hand"
                statusDetail = "Show one hand and separate your thumb and index finger."
            case .ready:
                statusTitle = "Ready to pinch"
                statusDetail = "Pinch, then drag left, right, up or down."
            case .confirmingPinch:
                statusTitle = "Hold your pinch…"
                statusDetail = "Keep your fingers together for a moment."
            case .scrolling:
                statusTitle = "Pinch engaged"
                statusDetail = "Drag along your chosen direction. Hold still to stop. Release to reset."
            }
        }
    }

    private func cancelPulse() {
        pulseGeneration &+= 1
        pendingPulse = nil
        pulseTask?.cancel()
        pulseTask = nil
    }

    private func deliverPulseAfterDelay(_ movement: ScrollMovement) {
        debugResult = "Panel closed. Pulse scheduled in 3 seconds."
        let generation = pulseGeneration
        pulseTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled, let self, self.pulseGeneration == generation,
                  !self.menuIsOpen, !self.systemSuspended else { return }
            let direction: String
            switch movement.axis {
            case .horizontal: direction = movement.pixels > 0 ? "content right" : "content left"
            case .vertical: direction = movement.pixels > 0 ? "later" : "earlier"
            }
            self.debugResult = self.sink.post(movement)
                ? "Sent \(direction) pulse. Verify the other app kept focus."
                : "Pulse blocked. Check Accessibility permission."
        }
    }
}
