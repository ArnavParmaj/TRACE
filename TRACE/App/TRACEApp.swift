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
        }
        .modelContainer(container)
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { recorder.saveNow() }   // a swipe-kill follows backgrounding
        }
    }
}
