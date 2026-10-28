import CoreLocation
import CoreMotion
import SwiftUI
import UserNotifications

/// S01: bike → odometer → permissions. Also the add-bike flow (Bike tab, Settings), without step 3.
struct OnboardingView: View {
    /// First launch also asks for permissions and states that data stays on the phone.
    var firstRun = false
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var step = 1
    @State private var name = ""
    @State private var registration = ""
    @State private var odo = ""
    @State private var asked: Set<Permission> = []
    @State private var location = CLLocationManager()
    @State private var altimeter = CMAltimeter()
    @State private var error: String?
    @State private var answers: [Permission: Answer] = [:]
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase

    /// Set once setup is finished or skipped, so first launch shows it only once.
    @AppStorage("onboarded") private var onboarded = false

    private var garage: Garage { Garage(context: context, user: LocalStubUser.load()) }
    private var steps: Int { firstRun ? 3 : 2 }
    private var trimmedName: String { name.trimmingCharacters(in: .whitespaces) }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    switch step {
                    case 1: bikeStep
                    case 2: odometerStep
                    default: permissionStep
                    }
                    if let error { Text(error).font(.condensed(13)).foregroundStyle(Color.alarmInk) }
                }
                .padding(20)
            }
            .scrollDismissesKeyboard(.interactively)
            bottomBar
        }
        .background(Color.ground.ignoresSafeArea())
        .animation(.easeOut(duration: 0.18), value: step)
        // A system prompt makes the app inactive; back to active means it was answered.
        .task(id: scenePhase) { if step == 3 { answers = await Permission.current() } }
        .task(id: step) { if step == 3 { answers = await Permission.current() } }
    }

    // MARK: Chrome

    private var topBar: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                if step > 1 && step < 3 {
                    Button { step -= 1 } label: {
                        Text("‹ BACK").font(.oswald(15, .semibold)).tracking(1.5).foregroundStyle(Color.inkDim)
                            .frame(minWidth: minTouch, minHeight: minTouch, alignment: .leading).contentShape(Rectangle())
                    }
                    .buttonStyle(PressStyle())
                } else {
                    Text("TRACE").font(.oswald(22, .bold)).tracking(1.4).foregroundStyle(Color.ink)
                        .frame(minHeight: minTouch)
                }
                Spacer()
                Text("STEP \(step) OF \(steps)").font(.oswald(13, .medium)).tracking(2).foregroundStyle(Color.inkMuted)
                if !firstRun {
                    Button { dismiss() } label: {
                        Text("CLOSE").font(.oswald(15, .semibold)).tracking(1.5).foregroundStyle(Color.inkDim)
                            .frame(minWidth: minTouch, minHeight: minTouch).contentShape(Rectangle())
                    }
                    .buttonStyle(PressStyle())
                }
            }
            HStack(spacing: 6) {
                ForEach(1...steps, id: \.self) { i in
                    Rectangle().fill(i <= step ? Color.accent : Color.surfaceLine).frame(height: 3)
                }
            }
            .accessibilityHidden(true)
        }
        .padding(.horizontal, 20).padding(.bottom, 14)
        .background { Hatch() }
        .overlay(alignment: .bottom) { Rectangle().fill(Color.surfaceRule).frame(height: 1) }
    }

    @ViewBuilder private var bottomBar: some View {
        VStack(spacing: 8) {
            switch step {
            case 1:
                PrimaryButton("NEXT", enabled: !trimmedName.isEmpty) { step = 2 }
                if firstRun { TextAction("SET UP LATER") { finish() } }   // no screen without a way out
            case 2:
                PrimaryButton(firstRun ? "NEXT" : "SAVE BIKE", enabled: Int(odo) != nil) { saveBike() }
                TextAction("I DON'T KNOW IT · SKIP") { odo = "0"; saveBike() }
            default:
                PrimaryButton("START USING TRACE") { finish() }
            }
        }
        .padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 8)
        .overlay(alignment: .top) { Rectangle().fill(Color.surfaceRule).frame(height: 1) }
    }

    // MARK: Steps

    @ViewBuilder private var bikeStep: some View {
        title("YOUR BIKE")
        Text(firstRun ? "What do you call it? You can add more bikes later in Settings." : "What do you call it?")
            .font(.condensed(16)).foregroundStyle(Color.inkDim)
        FieldBox("NAME", text: $name, prompt: "CB350")
        FieldBox("REGISTRATION (OPTIONAL)", text: $registration, prompt: "MH 02 AB 1234")
    }

    @ViewBuilder private var odometerStep: some View {
        title("ODOMETER")
        Text("The number on the dash right now. Service reminders count from it.")
            .font(.condensed(16)).foregroundStyle(Color.inkDim)
        Text(odo.isEmpty ? "—" : "\((Int(odo) ?? 0).formatted()) KM")
            .font(.oswald(56, .bold, relativeTo: .largeTitle)).monospacedDigit()
            .foregroundStyle(odo.isEmpty ? Color.inkFaint : Color.ink).lineLimit(1).minimumScaleFactor(0.6)
            .accessibilityLabel(odo.isEmpty ? "No reading yet" : "\(odo) kilometres")
        KeypadGrid { odo = Keypad.apply($0, to: odo, decimals: 0, maxWhole: 7) }
    }

    @ViewBuilder private var permissionStep: some View {
        title("PERMISSIONS")
        Text("What each one is for. You can change them later in iPhone Settings.")
            .font(.condensed(16)).foregroundStyle(Color.inkDim)
        ForEach(Permission.allCases, id: \.self) { p in
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(p.title).font(.oswald(17, .semibold)).tracking(1.2).foregroundStyle(Color.ink)
                    Text(p.why).font(.condensed(15)).foregroundStyle(Color.inkDim).fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                // What iOS actually answered, not just that we asked. OFF leads to Settings.
                let state = answers[p] ?? (asked.contains(p) ? .asked : .unasked)
                Button {
                    if state == .off, let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) } else { ask(p) }
                } label: {
                    Text(state.label).font(.oswald(15, .semibold)).tracking(1.5)
                        .foregroundStyle(state == .unasked || state == .off ? Color.ink : Color.inkMuted)
                        .frame(minWidth: 96, minHeight: minTouch)
                        .padding(.horizontal, 8)
                        .overlay {
                            Rectangle().stroke(state == .unasked || state == .off ? Color.accent : Color.surfaceRule,
                                               lineWidth: state == .unasked || state == .off ? 2 : 1)
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(PressStyle())
                .disabled(state == .on || state == .asked)
            }
            .padding(.vertical, 12)
            .overlay(alignment: .bottom) { Rectangle().fill(Color.surfaceLine).frame(height: 1) }
        }
        VStack(alignment: .leading, spacing: 4) {
            Text("NO ACCOUNT. NO CLOUD.").font(.oswald(15, .semibold)).tracking(2).foregroundStyle(Color.ink)
            Text("Everything stays on this phone. There is no backup, so deleting the app deletes your data.")
                .font(.condensed(15)).foregroundStyle(Color.inkDim).fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay { Rectangle().stroke(Color.surfaceRule, lineWidth: 1) }
        .padding(.top, 8)
    }

    private func title(_ text: String) -> some View {
        Text(text).font(.oswald(40, .bold, relativeTo: .largeTitle)).tracking(0.8).foregroundStyle(Color.ink)
            .accessibilityAddTraits(.isHeader)
    }

    // MARK: Actions

    private func saveBike() {
        let reg = registration.trimmingCharacters(in: .whitespaces)
        do {
            try garage.addBike(name: trimmedName, registration: reg.isEmpty ? nil : reg.uppercased(), odometerKm: Int(odo) ?? 0)
            error = nil
            if firstRun { step = 3 } else { finish() }
        } catch { self.error = "Couldn't save the bike: \(error.localizedDescription)" }
    }

    private func finish() {
        onboarded = true
        dismiss()
    }

    /// Each system prompt appears once; after that iOS answers silently, so the row just says ASKED.
    private func ask(_ p: Permission) {
        asked.insert(p)
        switch p {
        case .location:
            location.requestWhenInUseAuthorization()   // "Always" comes at the first ride start
        case .motion:
            guard CMAltimeter.isRelativeAltitudeAvailable() else { return }
            let altimeter = altimeter
            altimeter.startRelativeAltitudeUpdates(to: .main) { _, _ in altimeter.stopRelativeAltitudeUpdates() }
        case .notifications:
            Task { _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) }
        }
    }

    enum Answer: Equatable {
        case unasked, asked, on, off
        var label: String {
            switch self {
            case .unasked: "ALLOW"
            case .asked: "ASKED"
            case .on: "ALLOWED"
            case .off: "SETTINGS ›"
            }
        }
    }

    enum Permission: CaseIterable {
        case location, motion, notifications

        /// What iOS has recorded for each; a permission never asked is left out.
        @MainActor static func current() async -> [Permission: Answer] {
            var out: [Permission: Answer] = [:]
            switch CLLocationManager().authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways: out[.location] = .on
            case .denied, .restricted: out[.location] = .off
            default: break
            }
            switch CMAltimeter.authorizationStatus() {
            case .authorized: out[.motion] = .on
            case .denied, .restricted: out[.motion] = .off
            default: break
            }
            switch await UNUserNotificationCenter.current().notificationSettings().authorizationStatus {
            case .authorized, .provisional, .ephemeral: out[.notifications] = .on
            case .denied: out[.notifications] = .off
            default: break
            }
            return out
        }

        var title: String {
            switch self {
            case .location: "LOCATION"
            case .motion: "MOTION"
            case .notifications: "NOTIFICATIONS"
            }
        }

        var why: String {
            switch self {
            case .location: "Draws your route and measures distance while a ride is on."
            case .motion: "Reads the barometer to measure climb."
            case .notifications: "Service due, PUC or insurance about to expire."
            }
        }
    }
}
