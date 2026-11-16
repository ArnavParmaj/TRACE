import AppIntents
#if !WIDGET_EXTENSION
import CoreLocation
#endif

/// The Action Button press (decision 33) and the Live Activity LOG button (S18): always
/// writes a draft, ride or no ride, and returns. Runs without opening the app, phone locked.
/// Compiled into the widget too, so its button can name it; it always runs in the app.
struct LogEntryIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Log entry"
    static let description = IntentDescription("Saves a draft with the time and place. Complete it later on Today.")
    static let openAppWhenRun = false
    static let authenticationPolicy = IntentAuthenticationPolicy.alwaysAllowed

    /// The home-screen widget's LOG asks for a notification: nothing else on the home screen says it worked.
    /// The Action Button has the system tick and the Live Activity its count, so they leave it off.
    @Parameter(title: "Confirm with a notification", default: false) var confirm: Bool

    init() {}
    init(confirm: Bool) { self.confirm = confirm }

    @MainActor
    func perform() async throws -> some IntentResult {
        #if !WIDGET_EXTENSION
        // Last known fix only: asking for a fresh one could take seconds (invariant 7).
        let place = CLLocationManager().location?.coordinate
        try Capture(context: Store.shared.mainContext, user: LocalStubUser.load())
            .log(lat: place?.latitude, lon: place?.longitude)
        WidgetFeed.refresh(context: Store.shared.mainContext, recorder: nil, logged: confirm)   // the widget's log count
        if confirm { Reminders.confirmLogged() }
        #endif
        return .result()   // no dialog: it adds a Done tap; the system ✓ is the confirmation
    }
}

#if !WIDGET_EXTENSION
/// Makes the intent pickable under Settings › Action Button › Shortcut, no setup needed.
struct TRACEShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: LogEntryIntent(), phrases: ["Log in \(.applicationName)"],
                    shortTitle: "Log entry", systemImageName: "square.and.pencil")
    }
}
#endif
