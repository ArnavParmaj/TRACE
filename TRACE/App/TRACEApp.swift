import SwiftData
import SwiftUI

@main
struct TRACEApp: App {
    let container: ModelContainer
    @State private var recorder: RideRecorder
    @State private var undo = UndoCenter()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "-restoreFrom"), i + 1 < args.count { DebugSeed.restore(from: args[i + 1]) }   // simulator tests only
        let store = Store.shared
        container = store
        if ProcessInfo.processInfo.arguments.contains("-seedLongRide") {
            DebugSeed.longRide(context: store.mainContext, user: LocalStubUser.load())   // simulator timing test only
        }
        _recorder = State(initialValue: RideRecorder(context: store.mainContext, user: LocalStubUser.load(),
                                                     sensors: LocationService()))
    }

    var body: some Scene {
        WindowGroup {
            RootView().preferredColorScheme(.dark).environment(recorder).environment(undo)
                .onReceive(NotificationCenter.default.publisher(for: .draftCaptured)) { _ in syncActivity() }
        }
        .modelContainer(container)
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { recorder.saveNow() }   // a swipe-kill follows backgrounding
        }
        // S18 Live Activity: on start, pause, stop, each 100 m and each draft.
        .onChange(of: recorder.phase) { syncActivity() }
        .onChange(of: Int(recorder.stats.distanceM / 100)) { syncActivity() }
    }

    @MainActor private func syncActivity() {
        RideActivityController.sync(recorder, capture: Capture(context: container.mainContext, user: LocalStubUser.load()))
    }
}
