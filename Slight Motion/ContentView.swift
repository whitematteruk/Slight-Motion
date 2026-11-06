import SwiftUI
import AppKit

private let motionAccent = Color(red: 0.15, green: 0.66, blue: 0.56)

struct ContentView: View {
    @ObservedObject var controller: MotionController
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.bottom, 20)

            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 7) {
                    Circle()
                        .fill(controller.isEnabled ? motionAccent : Color.secondary.opacity(0.5))
                        .frame(width: 6, height: 6)
                    Text(controller.statusTitle)
                        .font(.system(size: 13, weight: .semibold))
                }
                Text(controller.statusDetail)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(2)
            }
            .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
            .padding(14)
            .background(.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 12))
            .padding(.bottom, 16)

            Button(action: controller.toggleEnabled) {
                HStack(spacing: 8) {
                    Image(systemName: controller.isEnabled ? "pause.fill" : "hand.pinch")
                    Text(controller.isEnabled ? "Disable gesture scrolling" : "Enable gesture scrolling")
                }
                .font(.system(size: 13, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
            }
            .buttonStyle(.borderedProminent)
            .tint(motionAccent)
            .controlSize(.large)
            .accessibilityIdentifier("toggleGestureScrolling")

            if controller.cameraError != nil && controller.isEnabled {
                Button("Retry camera", action: controller.retryCamera)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
            }

            instructions
                .padding(.vertical, 20)

            if controller.needsPermissions {
                Divider()
                permissions
                    .padding(.vertical, 16)
            }

            Divider()
            HStack(spacing: 5) {
                Image(systemName: "lock.shield")
                Text("On your Mac. No video saved.")
                Spacer(minLength: 0)
                Button("Quit", action: controller.quit)
                    .keyboardShortcut("q")
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
            }
            .font(.system(size: 10.5))
            .foregroundStyle(.tertiary)
            .padding(.top, 13)

            #if DEBUG
            if controller.diagnosticsEnabled {
                Divider().padding(.top, 14)
                VStack(alignment: .leading, spacing: 8) {
                    Text("DEVELOPMENT · EXTERNAL SCROLL TEST")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.secondary)
                    HStack {
                        Button("Later in 3s") { pulse(60) }
                        Button("Earlier in 3s") { pulse(-60) }
                    }
                    .disabled(controller.isEnabled)
                    if let result = controller.debugResult {
                        Text(result).font(.caption).foregroundStyle(.secondary)
                    }
                }
                .padding(.top, 12)
            }
            #endif
        }
        .padding(22)
        .frame(width: 352)
        .background(MenuVisibilityObserver(onChange: controller.menuVisibilityChanged))
        .onAppear { controller.menuVisibilityChanged(true) }
        .onDisappear { controller.menuVisibilityChanged(false) }
    }

    private var header: some View {
        HStack(spacing: 11) {
            Image(systemName: "hand.pinch")
                .font(.system(size: 24, weight: .light))
                .foregroundStyle(motionAccent)
                .frame(width: 43, height: 43)
                .background(motionAccent.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 3) {
                Text("Slight Motion")
                    .font(.system(size: 19, weight: .semibold, design: .rounded))
                Text("A little movement. Keep reading.")
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
    }

    private var instructions: some View {
        VStack(alignment: .leading, spacing: 13) {
            instruction("cursorarrow", title: "Point at your page", detail: "Leave the pointer over the text you want to scroll.")
            instruction("hand.pinch", title: "Pinch, then move", detail: "Move up to read on. Move down to go back.")
            instruction("hand.raised.fingers.spread", title: "Release and get comfortable", detail: "Open your fingers to reset. Pinch again anywhere.")
        }
    }

    private func instruction(_ symbol: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 11) {
            Image(systemName: symbol)
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
                .frame(width: 21, height: 20)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 12, weight: .medium))
                Text(detail)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(1)
            }
        }
    }

    private var permissions: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("TWO PERMISSIONS TO GET STARTED")
                .font(.system(size: 9, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(.secondary)
            permissionRow("Camera", detail: controller.cameraPermissionLabel, allowed: controller.cameraPermission == .granted) {
                controller.openSettings(camera: true)
            }
            permissionRow("Accessibility", detail: controller.accessibilityGranted ? "Allowed" : "Allow in Settings", allowed: controller.accessibilityGranted) {
                controller.openSettings(camera: false)
            }
            Text("Camera recognises your hand. Accessibility allows scrolling in other apps. Manage access in System Settings → Privacy & Security.")
                .font(.system(size: 10.5))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(2)
            Button("Check permissions", action: controller.requestPermissions)
                .buttonStyle(.link)
                .font(.system(size: 11, weight: .medium))
                .padding(.top, 2)
        }
    }

    private func permissionRow(_ title: String, detail: String, allowed: Bool, action: @escaping () -> Void) -> some View {
        HStack {
            Label(title, systemImage: allowed ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(allowed ? motionAccent : .secondary)
            Spacer()
            if allowed {
                Text(detail).foregroundStyle(.secondary)
            } else {
                Button(detail, action: action).buttonStyle(.link)
            }
        }
        .font(.system(size: 11))
    }

    private func pulse(_ pixels: Int) {
        controller.queueDiagnosticPulse(pixels)
        dismiss()
    }
}

/// MenuBarExtra window content can stay mounted while hidden. Observe its actual
/// visibility as well as appearance, so opening the panel always cancels a pinch.
private struct MenuVisibilityObserver: NSViewRepresentable {
    var onChange: (Bool) -> Void

    func makeNSView(context: Context) -> VisibilityView {
        let view = VisibilityView()
        view.onChange = onChange
        return view
    }

    func updateNSView(_ nsView: VisibilityView, context: Context) { nsView.onChange = onChange }

    final class VisibilityView: NSView {
        var onChange: ((Bool) -> Void)?
        private var visibilityObservation: NSKeyValueObservation?
        private var notifications: [NotificationToken] = []

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            visibilityObservation?.invalidate()
            notifications.removeAll()
            guard let window else { return }
            visibilityObservation = window.observe(\.isVisible, options: [.initial, .new]) { [weak self] window, _ in
                // AppKit changes window visibility on its main thread. Suspend
                // synchronously, before a queued camera callback can post output.
                MainActor.assumeIsolated { self?.onChange?(window.isVisible) }
            }
            for name in [NSWindow.didBecomeKeyNotification, NSWindow.didChangeOcclusionStateNotification] {
                notifications.append(NotificationToken(center: .default, name: name, object: window) { [weak self, weak window] _ in
                    MainActor.assumeIsolated {
                        guard let window else { return }
                        self?.onChange?(window.isVisible)
                    }
                })
            }
        }

        deinit {
            visibilityObservation?.invalidate()
        }
    }
}
