import SwiftData
import SwiftUI
import UserNotifications

@main
struct TRACEApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
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
            content.preferredColorScheme(.dark)
                // shortcut: dense dash layout breaks past xxxLarge (tab labels wrap, odometer clips); redo layouts to lift the cap.
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge).environment(recorder).environment(undo)
                .onReceive(NotificationCenter.default.publisher(for: .draftCaptured)) { _ in syncActivity(); feedWidget() }
        }
        .modelContainer(container)
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { recorder.saveNow() }   // a swipe-kill follows backgrounding
            if phase != .active { feedWidget() }   // whatever was edited in the app reaches the widget
        }
        .onChange(of: recorder.phase) { feedWidget() }
        // Asked once, so the widget's LOG can confirm with a notification (decision 93).
        .onChange(of: scenePhase, initial: true) { _, phase in
            if phase == .active { UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in } }
        }
        // S18 Live Activity: on start, pause, stop, each 100 m and each draft.
        .onChange(of: recorder.phase) { syncActivity() }
        .onChange(of: Int(recorder.stats.distanceM / 100)) { syncActivity() }
    }

    @ViewBuilder private var content: some View {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-widgetGallery") { WidgetGallery() } else { RootView() }   // simulator screenshots only
        #else
        RootView()
        #endif
    }

    @MainActor private func feedWidget() { WidgetFeed.refresh(context: container.mainContext, recorder: recorder) }

    @MainActor private func syncActivity() {
        RideActivityController.sync(recorder, capture: Capture(context: container.mainContext, user: LocalStubUser.load()))
    }
}
