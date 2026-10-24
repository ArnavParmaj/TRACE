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

    @MainActor
    func perform() async throws -> some IntentResult {
        #if !WIDGET_EXTENSION
        // Last known fix only: asking for a fresh one could take seconds (invariant 7).
        let place = CLLocationManager().location?.coordinate
        try Capture(context: Store.shared.mainContext, user: LocalStubUser.load())
            .log(lat: place?.latitude, lon: place?.longitude)
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
