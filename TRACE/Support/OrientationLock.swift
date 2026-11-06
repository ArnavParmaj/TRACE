import UIKit

/// Portrait everywhere except Ride mode, which also rotates to either landscape (decision 85).
@MainActor
enum OrientationLock {
    static var mask: UIInterfaceOrientationMask = .portrait

    static func set(_ new: UIInterfaceOrientationMask) {
        mask = new
        let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene
        scene?.keyWindow?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
        // Leaving Ride mode while sideways must snap back, not wait for the next rotation.
        if new == .portrait { scene?.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait)) { _ in } }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        MainActor.assumeIsolated { OrientationLock.mask }
    }
}
