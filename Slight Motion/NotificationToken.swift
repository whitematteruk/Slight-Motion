import Foundation

/// NotificationCenter tokens are opaque reference values. This owner removes its
/// observer on destruction, including when an observing view leaves its window.
final class NotificationToken: @unchecked Sendable {
    private let center: NotificationCenter
    private let token: NSObjectProtocol

    init(center: NotificationCenter, name: Notification.Name, object: Any? = nil,
         handler: @escaping @Sendable (Notification) -> Void) {
        self.center = center
        token = center.addObserver(forName: name, object: object, queue: .main, using: handler)
    }

    deinit { center.removeObserver(token) }
}
