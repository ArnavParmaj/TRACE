import SwiftData
import SwiftUI

/// S02 Today: 01 RIDE, 02 DRAFTS, 03 DUE, 04 THIS WEEK, 05 RECENT. Empty sections hide, except 01.
struct TodayView: View {
    @Environment(RideRecorder.self) private var recorder
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @State private var drafts: [CaptureDraft] = []
    @State private var due: [(label: String, status: DueStatus)] = []
    @State private var completing: CaptureDraft?
    @State private var showRide = false
    @State private var recap: Ride?
    @State private var shownRecap: UUID?   // the recap is shown once per ride
    @State private var week = Week()
    @State private var recent: [Recent] = []
    @State private var bikeLine: String?
    @State private var openRide: Ride?
    @State private var editing: Expense?
    @State private var settings = false
    @State private var error: String?

    private var capture: Capture { Capture(context: context, user: LocalStubUser.load()) }
    private var garage: Garage { Garage(context: context, user: LocalStubUser.load()) }
    private var ledger: Ledger { Ledger(context: context, user: LocalStubUser.load()) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                header
                rideSection
                if !drafts.isEmpty { draftSection }
                if !due.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        SectionHead(number: "03", title: "DUE").padding(.bottom, 4)
                        ForEach(due.indices, id: \.self) { DueRow(label: due[$0].label, status: due[$0].status) }
                    }
                }
                if week.hasData { weekSection }
                if !recent.isEmpty { recentSection }
                if let error {
                    Text(error).font(.condensed(13)).foregroundStyle(Color.alarmInk)
                }
            }
            .padding(.horizontal, 20).padding(.bottom, 20)
            .animation(.easeOut(duration: 0.2), value: drafts.count + due.count)
        }
        .task(id: scenePhase) { if scenePhase == .active { reload() } }
        .onReceive(NotificationCenter.default.publisher(for: .draftCaptured)) { _ in reload() }
        // The Live Activity opens Ride mode (S18).
        .onOpenURL { url in if url.host == "ride", recorder.phase != .idle { showRide = true } }
        .sheet(item: $completing, onDismiss: reload) { DraftSheet(start: $0, capture: capture, ledger: ledger) }
        .sheet(item: $recap, onDismiss: reload) { RideSheet(ride: $0, isRecap: true) }
        .sheet(item: $openRide, onDismiss: reload) { RideSheet(ride: $0) }
        .sheet(isPresented: $settings, onDismiss: reload) { SettingsView() }
        .sheet(item: $editing, onDismiss: reload) { ExpenseSheet(expense: $0, capture: capture, ledger: ledger) }
        .fullScreenCover(isPresented: $showRide, onDismiss: showRecap) { rideScreen }
        // START has no press haptic; the outcome is the confirmation (decision 52).
        .sensoryFeedback(.success, trigger: recorder.phase) { old, new in old == .idle && new == .recording }
        // A ride that ends (END RIDE, END AT, auto-close) drops back to Today, then shows its recap (S05).
        .onChange(of: recorder.phase) { _, _ in rideEnded() }
        .onChange(of: recorder.orphan == nil) { _, _ in rideEnded() }   // END AT on an unfinished ride
    }

    private var header: some View {
        ScreenHeader(title: "TRACE", hatched: true) {
            Text(Date.now.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)).uppercased())
                .font(.oswald(14, .medium)).tracking(1.7).foregroundStyle(Color.inkMuted)
            Button { settings = true } label: {
                Image(systemName: "gearshape").font(.system(size: 22, weight: .regular)).foregroundStyle(Color.inkDim)
                    .frame(width: minTouch, height: minTouch).contentShape(Rectangle())
            }
            .buttonStyle(PressStyle())
            .accessibilityLabel("Settings")
            .padding(.trailing, -14)   // icon sits on the screen margin, target stays 60pt
        }
    }

    // MARK: 01 RIDE

    @ViewBuilder private var rideSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHead(number: "01", title: "RIDE")
            if recorder.orphan != nil {
                rideRow("UNFINISHED RIDE", detail: "RESOLVE ›")
            } else if recorder.phase == .idle {
                CaptureButton(title: "START RIDE", subtitle: bikeLine) {
                    // No bike added yet: the ride still records, against no vehicle.
                    let bike = try? garage.bike()
                    recorder.start(vehicleID: bike?.id ?? .unowned, odoStartKm: bike.flatMap { try? garage.startReading($0) })
                    showRide = true   // straight to the live numbers
                }
                if drafts.isEmpty && due.isEmpty && recent.isEmpty {
                    Text("Press the Action Button any time to log. Start a ride here.")
                        .font(.condensed(15)).foregroundStyle(Color.inkDim)
                }
            } else {
                let label = recorder.phase == .paused ? "PAUSED" : "RIDING"
                rideRow("\(label)  \(elapsed)  \(String(format: "%.1f KM", recorder.stats.distanceM / 1000))",
                        detail: "OPEN ›")
            }
        }
    }

    private var elapsed: String {
        let s = Int(recorder.ride.flatMap { r in recorder.lastFix.map { $0.time.timeIntervalSince(r.startedAt) } } ?? 0)
        return String(format: "%d:%02d:%02d", s / 3600, s / 60 % 60, s % 60)
    }

    private func rideRow(_ text: String, detail: String) -> some View {
        Button { showRide = true } label: {
            HStack {
                Text(text).font(.oswald(20, .medium)).monospacedDigit().foregroundStyle(Color.ink)
                Spacer()
                Text(detail).font(.oswald(15, .semibold)).tracking(1.5).foregroundStyle(Color.accent)
            }
            .padding(.leading, 20).padding(.trailing, 16)
            .frame(minHeight: 72)
            .overlay { Rectangle().stroke(Color.accent, lineWidth: 2) }
            .overlay(alignment: .leading) { Rectangle().fill(Color.accent).frame(width: 6) }
            .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
    }

    private var rideScreen: some View { RideModeView().environment(recorder) }

    // MARK: 02 DRAFTS

    private var draftSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHead(number: "02", title: "DRAFTS", count: drafts.count)
                .padding(.bottom, 4)
            ForEach(drafts.prefix(3)) { draft in
                Button { completing = draft } label: { draftRow(draft) }
                    .buttonStyle(PressStyle())
            }
            if drafts.count > 3 {
                Button { completing = drafts.first } label: {
                    Text("ALL \(drafts.count) DRAFTS ›")
                        .font(.oswald(15, .semibold)).tracking(1.5).foregroundStyle(Color.accent)
                        .frame(maxWidth: .infinity, minHeight: minTouch, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PressStyle())
            }
        }
    }

    private func draftRow(_ draft: CaptureDraft) -> some View {
        HStack(spacing: 16) {
            Text(draft.capturedAt.formatted(date: .omitted, time: .shortened))
                .font(.oswald(20, .medium)).monospacedDigit().foregroundStyle(Color.ink)
            // shortcut: no place name yet (needs reverse geocoding); "ON RIDE" says enough to place it.
            Text(draft.rideID == nil ? "Draft" : "Draft · on ride")
                .font(.condensed(17)).foregroundStyle(Color.inkDim)
            Spacer()
            Text("COMPLETE ›").font(.oswald(15, .semibold)).tracking(1.5).foregroundStyle(Color.accent)
        }
        .frame(minHeight: minTouch)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.surfaceLine).frame(height: 1) }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private func rideEnded() {
        guard recorder.phase == .idle, recorder.orphan == nil else { return }
        if showRide { showRide = false } else { showRecap() }   // the cover's onDismiss shows it: no sheet over a closing cover
    }

    // MARK: 04 THIS WEEK

    private var weekSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHead(number: "04", title: "THIS WEEK")
            HStack(spacing: 6) {
                ForEach(0..<7, id: \.self) { i in
                    let rode = week.rideDays.contains(i)
                    VStack(spacing: 6) {
                        Text(["M", "T", "W", "T", "F", "S", "S"][i]).font(.oswald(14, .medium))
                            .foregroundStyle(rode ? Color.ink : Color.inkFaint)
                        Rectangle().fill(rode ? Color.accent : Color.surfaceLine).frame(width: 16, height: 3)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 8)
                    .overlay { Rectangle().stroke(i == week.today ? Color.inkMuted : .clear, lineWidth: 1) }
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Rode \(week.rideDays.count) of 7 days this week")
            Text([String(format: week.km < 100 ? "%.1f KM" : "%.0f KM", week.km), Money.format(week.spentMinor),
                  week.kmPerL.map { String(format: "%.1f KM/L", $0) } ?? "— KM/L"].joined(separator: "  ·  "))
                .font(.oswald(22, .semibold)).monospacedDigit().foregroundStyle(Color.ink)
            if week.kmPerL == nil {
                Text("km/L needs two full-tank fills in a row.").font(.condensed(13)).foregroundStyle(Color.inkMuted)
            }
        }
    }

    // MARK: 05 RECENT

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHead(number: "05", title: "RECENT").padding(.bottom, 4)
            ForEach(recent) { item in
                Button {
                    switch item { case .ride(let r, _): openRide = r; case .expense(let e): editing = e }
                } label: { recentRow(item) }
                .buttonStyle(PressStyle())
            }
        }
    }

    private func recentRow(_ item: Recent) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(item.date.formatted(.dateTime.weekday(.abbreviated)).uppercased())
                .font(.oswald(13, .medium)).tracking(1).foregroundStyle(Color.inkMuted).frame(width: 40, alignment: .leading)
            VStack(alignment: .leading, spacing: 3) {
                Text(item.title).font(.condensed(17)).foregroundStyle(Color.ink).lineLimit(2)
                if let sub = item.subtitle { Text(sub).font(.condensed(13)).foregroundStyle(Color.inkMuted) }
            }
            Spacer(minLength: 8)
            if let minor = item.amountMinor {
                Text(Money.format(minor)).font(.oswald(17, .semibold)).monospacedDigit().foregroundStyle(Color.ink).fixedSize()
            }
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.surfaceLine).frame(height: 1) }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private func showRecap() {
        if let closed = recorder.lastClosed, closed.id != shownRecap { shownRecap = closed.id; recap = closed }
    }

    private func reload() {
        do {
            drafts = try capture.pending()
            due = try garage.dueItems()
            let bike = try garage.bike()
            bikeLine = bike.map { "\($0.name.uppercased()) · ODO \($0.odometerKm.formatted()) KM" }
            let rides = recorder.finishedRides()
            let expenses = try ledger.all()
            week = Week(rides: rides, expenses: expenses)
            let totals = try ledger.totalsByRide()
            recent = Array((rides.prefix(3).map { Recent.ride($0, totals[$0.id]) }
                            + expenses.filter { $0.rideID == nil }.prefix(3).map(Recent.expense))
                .sorted { $0.date > $1.date }.prefix(3))
            error = nil
        } catch { self.error = "Couldn't load Today: \(error.localizedDescription)" }
        Reminders.refresh(garage)   // dates move on; re-plan whenever the app comes back
    }
}

/// [01] RIDE ──────── 2 : inverted number chip, spaced caps, hairline rule (DESIGN.md).
/// `value` is an amber figure at the end, e.g. a section's ₹ total.
struct SectionHead: View {
    let number: String
    let title: String
    var count: Int?
    var value: String?

    var body: some View {
        HStack(spacing: 10) {
            Text(number).font(.oswald(12, .semibold)).foregroundStyle(Color.ground)
                .padding(.horizontal, 6).padding(.vertical, 2).background(Color.inkMuted)
            Text(title).font(.oswald(13, .medium)).tracking(2.3).foregroundStyle(Color.inkDim)
            Rectangle().fill(Color.surfaceRule).frame(height: 1)
            if let trailing = value ?? count.map(String.init) {
                Text(trailing).font(.oswald(15, .semibold)).monospacedDigit().foregroundStyle(Color.accent)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

/// The 106pt capture button (DESIGN.md): black fill, amber border, amber spine.
struct CaptureButton: View {
    let title: String
    var subtitle: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.oswald(32, .bold)).tracking(1.3).foregroundStyle(Color.ink)
                if let subtitle {
                    Text(subtitle).font(.oswald(13, .medium)).tracking(1.3).foregroundStyle(Color.inkMuted)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 106, alignment: .leading)
            .padding(.leading, 28)
            .overlay { Rectangle().stroke(Color.accent, lineWidth: 2) }
            .overlay(alignment: .leading) { Rectangle().fill(Color.accent).frame(width: 10) }
            .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle(haptic: false))
    }
}

/// What 04 THIS WEEK shows: Monday-first, from finished rides and every expense.
struct Week {
    var rideDays: Set<Int> = []
    var today = 0
    var km = 0.0
    var spentMinor = 0
    var kmPerL: Double?
    var hasData: Bool { km > 0 || spentMinor > 0 }

    init() {}

    init(rides: [Ride], expenses: [Expense], now: Date = .now) {
        let cal = Calendar(identifier: .iso8601)
        guard let span = cal.dateInterval(of: .weekOfYear, for: now) else { return }
        let day = { (d: Date) in cal.dateComponents([.day], from: span.start, to: d).day ?? 0 }
        today = day(now)
        for r in rides where span.contains(r.startedAt) {
            rideDays.insert(day(r.startedAt))
            km += Double(r.distanceM) / 1000
        }
        spentMinor = expenses.filter { span.contains($0.occurredAt) }.reduce(0) { $0 + $1.amountMinor }
        kmPerL = Ledger.economy(expenses).last?.kmPerL
    }
}

/// One 05 RECENT row: a ride (with its ₹ total) or an expense not on any ride.
enum Recent: Identifiable {
    case ride(Ride, Int?)
    case expense(Expense)

    var id: UUID { switch self { case .ride(let r, _): r.id; case .expense(let e): e.id } }
    var date: Date { switch self { case .ride(let r, _): r.startedAt; case .expense(let e): e.occurredAt } }
    var amountMinor: Int? { switch self { case .ride(_, let t): t; case .expense(let e): e.amountMinor } }
    var title: String { switch self { case .ride(let r, _): r.displayName; case .expense(let e): e.category.rawValue.capitalized } }
    var subtitle: String? {
        switch self {
        case .ride(let r, _): String(format: "%.1f km · ", Double(r.distanceM) / 1000) + StatCell.clock(r.movingDurationS) + " moving"
        case .expense(let e): e.detailLine
        }
    }
}
