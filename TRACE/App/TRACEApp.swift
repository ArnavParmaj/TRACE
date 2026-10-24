import SwiftData
import SwiftUI

@main
struct TRACEApp: App {
    let container: ModelContainer
    @State private var recorder: RideRecorder
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let store = Store.shared
        container = store
        _recorder = State(initialValue: RideRecorder(context: store.mainContext, user: LocalStubUser.load(),
                                                     sensors: LocationService()))
    }

    var body: some Scene {
        WindowGroup {
            RootView().preferredColorScheme(.dark).environment(recorder)
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
