import SwiftData
import SwiftUI

@main
struct TRACEApp: App {
    // Crash rather than open a fresh empty store: silently losing the log is worse.
    let container: ModelContainer = {
        do { return try Store.container() } catch { fatalError("Store failed to open: \(error)") }
    }()

    var body: some Scene {
        WindowGroup {
            RootView().preferredColorScheme(.dark)
        }
        .modelContainer(container)
    }
}
