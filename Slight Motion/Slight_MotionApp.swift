import SwiftUI

@main
struct Slight_MotionApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var controller = MotionController()

    var body: some Scene {
        MenuBarExtra {
            ContentView(controller: controller)
        } label: {
            Image(systemName: controller.isEngaged ? "hand.pinch.fill" : "hand.pinch")
                .symbolRenderingMode(.monochrome)
                .accessibilityLabel(controller.isEngaged ? "Slight Motion — pinch engaged" : "Slight Motion — \(controller.statusTitle)")
        }
        .menuBarExtraStyle(.window)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}
