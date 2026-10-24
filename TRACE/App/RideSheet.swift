import SwiftData
import SwiftUI

extension Ride {
    /// The rider's name, else "Bandra → Lonavala", else the start date.
    var displayName: String {
        if let title { return title }
        if let from = startPlaceName { return endPlaceName.map { $0 == from ? from : "\(from) → \($0)" } ?? from }
        return startedAt.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)).uppercased()
    }

    /// "SAT 18 OCT · 08:14 – 11:05"; just the times when the name already is the date.
    var whenLine: String {
        let start = startedAt.formatted(date: .omitted, time: .shortened)
        let times = endedAt.map { "\(start) – \($0.formatted(date: .omitted, time: .shortened))" } ?? start
        guard title != nil || startPlaceName != nil else { return times }
        return startedAt.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)).uppercased() + " · " + times
    }
}

/// S05 recap, shown once when a ride stops; VIEW RIDE (or a tap on RIDES) shows the
/// ride view: stats and cost.
/// shortcut: S07's map, elevation and splits are M7; until then the ride view is stats + cost.
struct RideSheet: View {
    let ride: Ride
    var isRecap = false

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var detail = false
    @State private var attached: [Expense] = []
    @State private var detached: [Expense] = []   // detached on this screen; UNDO puts them back
    @State private var attachable: [Expense] = []
    @State private var drafts: [CaptureDraft] = []
    @State private var economy: [Economy] = []
    @State private var bike: Vehicle?
    @State private var picking = false
    @State private var editing: Expense?
    @State private var completing: CaptureDraft?
    @State private var odometer = false
    @State private var error: String?
    @State private var analysis: RideAnalysis?
    @State private var stops: [StopEvent] = []
    @State private var confirmDelete = false
    @Environment(RideRecorder.self) private var recorder

    private var ledger: Ledger { Ledger(context: context, user: LocalStubUser.load()) }
    private var capture: Capture { Capture(context: context, user: LocalStubUser.load()) }
    private var garage: Garage { Garage(context: context, user: LocalStubUser.load()) }
    private var totalMinor: Int { attached.reduce(0) { $0 + $1.amountMinor } }
    private var showsRecap: Bool { isRecap && !detail }

    var body: some View {
        VStack(spacing: 0) {
            if showsRecap { SheetBar(title: "") } else { SheetBar(title: ride.whenLine) }
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    if showsRecap { recapHead } else { detailHead }
                    if !showsRecap, let analysis { review(analysis) }
                    cost
                    if !drafts.isEmpty { draftSection }
                    if showsRecap, let bike { odometerSection(bike) }
                    if !showsRecap { deleteButton }
                    if let error { Text(error).font(.condensed(13)).foregroundStyle(Color.alarmInk) }
                }
                .padding(.horizontal, 20).padding(.vertical, 8)
                .animation(.easeOut(duration: 0.2), value: attached.map(\.id) + detached.map(\.id) + attachable.map(\.id))
            }
            if showsRecap { bottomBar }
        }
        .background(Color.ground.ignoresSafeArea())
        .presentationBackground(Color.ground)
        .task { reload() }
        .sheet(item: $editing, onDismiss: reload) { ExpenseSheet(expense: $0, capture: capture, ledger: ledger) }
        .sheet(item: $completing, onDismiss: reload) { DraftSheet(start: $0, capture: capture, ledger: ledger) }
        .sheet(isPresented: $odometer, onDismiss: reload) { if let bike { OdometerSheet(bike: bike, garage: garage) } }
        // Loaded after the sheet is up, so a long ride never delays it opening.
        .task(id: detail) { if !showsRecap && analysis == nil { loadReview() } }
        .alert("Delete this ride?", isPresented: $confirmDelete) {
            Button("Delete", role: .destructive) { recorder.delete(ride); dismiss() }
            Button("Cancel", role: .cancel) {}
        } message: { Text("Its route and stats are removed. Attached expenses stay in MONEY.") }
    }

    // MARK: Heads

    private var recapHead: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text("RIDE SAVED").font(.oswald(13, .medium)).tracking(2.6).foregroundStyle(Color.accent)
                Text(ride.displayName).font(.oswald(34, .bold, relativeTo: .largeTitle)).foregroundStyle(Color.ink)
                Text(ride.whenLine).font(.oswald(14, .medium)).tracking(1.4).foregroundStyle(Color.inkMuted)
            }
            .padding(.horizontal, 20).padding(.vertical, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background { Hatch() }
            .overlay(alignment: .bottom) { Rectangle().fill(Color.surfaceRule).frame(height: 1) }
            .padding(.horizontal, -20)
            statGrid([(km, "KM"), (StatCell.clock(ride.movingDurationS), "MOVING"),
                      ("+\(ride.climbM)", "M CLIMB"), (Money.format(totalMinor), "SPENT")], columns: 2, size: 32)
        }
    }

    private var detailHead: some View {
        VStack(alignment: .leading, spacing: 12) {
            Group {
                if let analysis, !analysis.segments.isEmpty {
                    RouteMap(analysis: analysis, stops: stops)
                } else {
                    Hatch(spacing: 18)
                }
            }
            .frame(height: 300)
            .overlay(alignment: .bottom) { Rectangle().fill(Color.surfaceRule).frame(height: 1) }
            .padding(.horizontal, -20).padding(.top, -8).padding(.bottom, 8)
            Text(ride.displayName).font(.oswald(28, .bold, relativeTo: .largeTitle)).foregroundStyle(Color.ink)
            SectionHead(number: "01", title: "STATS")
            statGrid([(km, "KM"), (StatCell.clock(ride.movingDurationS), "MOVING"),
                      (StatCell.clock(ride.elapsedDurationS), "ELAPSED"), ("+\(ride.climbM)", "M CLIMB"),
                      (String(format: "%.0f", ride.avgSpeedKph), "AVG KM/H"), (String(format: "%.0f", ride.maxSpeedKph), "MAX KM/H")],
                     columns: 3, size: 26)
        }
    }

    // MARK: 02 ELEVATION · 03 SPEED · 04 SPLITS

    @ViewBuilder private func review(_ a: RideAnalysis) -> some View {
        if a.elevation.count > 1 {
            VStack(alignment: .leading, spacing: 12) {
                SectionHead(number: "02", title: "ELEVATION")
                ElevationChart(analysis: a)
            }
        }
        VStack(alignment: .leading, spacing: 12) {
            SectionHead(number: "03", title: "SPEED")
            let total = max(1, a.bandSeconds.reduce(0, +))
            ForEach(RideAnalysis.Band.allCases, id: \.self) { band in
                let secs = a.bandSeconds[band.rawValue]
                HStack(spacing: 10) {
                    Text(band.label).font(.oswald(14, .medium)).monospacedDigit().foregroundStyle(Color.inkDim)
                        .frame(width: 56, alignment: .leading)
                    Rectangle().fill(Color.surfaceLine).frame(height: 6)
                        .overlay(alignment: .leading) {
                            GeometryReader { g in Rectangle().fill(band.color).frame(width: g.size.width * CGFloat(secs) / CGFloat(total)) }
                        }
                    Text(StatCell.clock(secs)).font(.oswald(16, .semibold)).monospacedDigit().foregroundStyle(Color.ink)
                        .frame(width: 64, alignment: .trailing)
                }
                .accessibilityElement(children: .combine)
            }
            Text("KM/H · TOP \(String(format: "%.0f", a.topSpeedKph)) · \(stopLine)")
                .font(.oswald(13, .medium)).tracking(1.2).foregroundStyle(Color.inkMuted)
        }
        if a.splits.count > 1 {
            VStack(alignment: .leading, spacing: 0) {
                SectionHead(number: "04", title: "SPLITS").padding(.bottom, 4)
                ForEach(a.splits.indices, id: \.self) { i in
                    let sp = a.splits[i]
                    let km = sp.toKm - Double(sp.fromKm)
                    HStack {
                        Text(Int(sp.toKm.rounded()) > sp.fromKm + 1 ? "KM \(sp.fromKm + 1)–\(Int(sp.toKm.rounded()))" : "KM \(sp.fromKm + 1)").foregroundStyle(Color.inkMuted)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(StatCell.clock(sp.seconds)).foregroundStyle(Color.ink)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(sp.seconds > 0 ? String(format: "%.0f KM/H", km / Double(sp.seconds) * 3600) : "—")
                            .foregroundStyle(Color.inkDim).frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .font(.oswald(15, .medium)).monospacedDigit()
                    .frame(minHeight: 44)
                    .overlay(alignment: .bottom) { Rectangle().fill(Color.surfaceLine).frame(height: 1) }
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }

    private var stopLine: String {
        let stopped = stops.reduce(0.0) { $0 + $1.endedAt.timeIntervalSince($1.startedAt) }
        return stops.isEmpty ? "NO STOPS" : "\(stops.count) \(stops.count == 1 ? "STOP" : "STOPS") · \(StatCell.clock(Int(stopped))) STOPPED"
    }

    private var deleteButton: some View {
        Button { confirmDelete = true } label: {
            Text("DELETE RIDE").font(.oswald(14, .medium)).tracking(2).foregroundStyle(Color.inkMuted)
                .frame(maxWidth: .infinity, minHeight: minTouch)
                .overlay { Rectangle().stroke(Color.surfaceRule, lineWidth: 1) }
                .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
        .disabled(recorder.ride?.id == ride.id)
    }

    private func loadReview() {
        let review = Review(context: context, user: LocalStubUser.load())
        do {
            stops = try review.stops(of: ride)
            analysis = try review.analysis(of: ride)
        } catch { self.error = "Couldn't load the route: \(error.localizedDescription)" }
    }

    private var km: String { String(format: "%.1f", Double(ride.distanceM) / 1000) }

    /// Ruled grid of stats; the SPENT cell is the one lit figure.
    private func statGrid(_ cells: [(String, String)], columns: Int, size: CGFloat) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: columns), spacing: 0) {
            ForEach(cells.indices, id: \.self) { i in
                VStack(alignment: .leading, spacing: 2) {
                    Text(cells[i].0).font(.oswald(size, .semibold)).monospacedDigit()
                        .foregroundStyle(cells[i].1 == "SPENT" ? Color.accent : Color.ink)
                        .lineLimit(1).minimumScaleFactor(0.6)
                    Text(cells[i].1).font(.oswald(12, .medium)).tracking(2.2).foregroundStyle(Color.inkMuted)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay { Rectangle().stroke(Color.surfaceRule, lineWidth: 0.5) }
                .accessibilityElement(children: .combine)
            }
        }
        .overlay { Rectangle().stroke(Color.surfaceRule, lineWidth: 0.5) }
    }

    // MARK: Cost

    private var cost: some View {
        VStack(alignment: .leading, spacing: 0) {
            if showsRecap {
                SectionHead(number: "01", title: "ATTACHED")
                if !attached.isEmpty {
                    Text("Logged while you rode, so they joined this ride.")
                        .font(.condensed(13)).foregroundStyle(Color.inkMuted).padding(.top, 6)
                }
            } else {
                SectionHead(number: "05", title: "COST", value: totalMinor > 0 ? Money.format(totalMinor) : nil)
            }
            if attached.isEmpty && detached.isEmpty {
                Text("Nothing attached to this ride.").font(.condensed(15)).foregroundStyle(Color.inkDim)
                    .frame(minHeight: minTouch, alignment: .leading)
            }
            ForEach(attached) { e in
                HStack(spacing: 8) {
                    Button { editing = e } label: { ExpenseRow(expense: e) }.buttonStyle(PressStyle())
                    smallButton("DETACH", lit: false) { run { try ledger.detach(e); detached.append(e) } }
                }
            }
            ForEach(detached) { e in
                HStack(spacing: 8) {
                    ExpenseRow(expense: e).opacity(0.4)
                    smallButton("UNDO", lit: false) {
                        run { try ledger.attach(e, to: ride); detached.removeAll { $0.id == e.id } }
                    }
                }
            }
            Button { picking.toggle() } label: {
                Text(picking ? "− HIDE" : "+ ATTACH AN EXPENSE").font(.oswald(13, .medium)).tracking(1.6)
                    .foregroundStyle(Color.inkDim)
                    .frame(maxWidth: .infinity, minHeight: minTouch, alignment: .leading).contentShape(Rectangle())
            }
            .buttonStyle(PressStyle())
            if picking {
                if attachable.isEmpty {
                    Text("No unattached expenses within a day of this ride.")
                        .font(.condensed(15)).foregroundStyle(Color.inkDim)
                }
                ForEach(attachable) { e in
                    HStack(spacing: 8) {
                        ExpenseRow(expense: e, showsDay: true)
                        smallButton("ATTACH", lit: true) { run { try ledger.attach(e, to: ride) } }
                    }
                }
            }
            if attached.contains(where: { $0.category == .fuel }) { economyLine }
        }
    }

    /// km/L for the interval a fill on this ride closed; W6 when there isn't one.
    private var economyLine: some View {
        let ids = Set(attached.map(\.id))
        let here = economy.last { ids.contains($0.closingID) }
        return HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(here.map { String(format: "%.1f KM/L", $0.kmPerL) } ?? "— KM/L")
                .font(.oswald(20, .semibold)).monospacedDigit().foregroundStyle(Color.ink)
            Text(here == nil ? "NEEDS TWO FULL-TANK FILLS IN A ROW" : "FULL TANK TO FULL TANK")
                .font(.oswald(13, .medium)).tracking(1).foregroundStyle(Color.inkMuted)
        }
    }

    // MARK: Drafts, odometer

    private var draftSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHead(number: showsRecap ? "02" : "06", title: "DRAFTS")
            Button { completing = drafts.first } label: {
                HStack {
                    Text(drafts.count == 1 ? "1 draft from this ride" : "\(drafts.count) drafts from this ride")
                        .font(.condensed(17)).foregroundStyle(Color.ink)
                    Spacer()
                    Text("COMPLETE ›").font(.oswald(13, .medium)).tracking(1.6).foregroundStyle(Color.accent)
                }
                .frame(minHeight: 64)
                .overlay(alignment: .bottom) { Rectangle().fill(Color.surfaceLine).frame(height: 1) }
                .contentShape(Rectangle())
            }
            .buttonStyle(PressStyle())
        }
    }

    /// Skippable: manual is authoritative, GPS only suggests (decision 24).
    private func odometerSection(_ bike: Vehicle) -> some View {
        let suggested = (try? garage.odometerSuggestion(bike)) ?? bike.odometerKm
        return VStack(alignment: .leading, spacing: 12) {
            SectionHead(number: drafts.isEmpty ? "02" : "03", title: "ODOMETER")
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(suggested.formatted()) KM?").font(.oswald(28, .semibold)).monospacedDigit().foregroundStyle(Color.ink)
                    Text("Suggested from GPS. Your reading wins.").font(.condensed(13)).foregroundStyle(Color.inkMuted)
                }
                Spacer()
                Button { odometer = true } label: {
                    Text("ENTER").font(.oswald(14, .medium)).tracking(1.7).foregroundStyle(Color.ink)
                        .frame(minWidth: 96, minHeight: minTouch)
                        .overlay { Rectangle().stroke(Color.surfaceRule, lineWidth: 1) }
                        .contentShape(Rectangle())
                }
                .buttonStyle(PressStyle())
            }
        }
    }

    private var bottomBar: some View {
        HStack(spacing: 10) {
            Button { withAnimation(.easeOut(duration: 0.2)) { detail = true } } label: {
                Text("VIEW RIDE").font(.oswald(16, .medium)).tracking(1.9).foregroundStyle(Color.inkDim)
                    .frame(maxWidth: .infinity, minHeight: 64)
                    .overlay { Rectangle().stroke(Color.surfaceRule, lineWidth: 1) }
                    .contentShape(Rectangle())
            }
            .buttonStyle(PressStyle())
            Button { dismiss() } label: {
                Text("DONE").font(.oswald(18, .bold)).tracking(2.2).foregroundStyle(Color.ink)
                    .frame(maxWidth: .infinity, minHeight: 64)
                    .overlay { Rectangle().stroke(Color.accent, lineWidth: 2) }
                    .contentShape(Rectangle())
            }
            .buttonStyle(PressStyle())
        }
        .padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 8)
        .overlay(alignment: .top) { Rectangle().fill(Color.surfaceRule).frame(height: 1) }
    }

    private func smallButton(_ title: String, lit: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.oswald(13, .medium)).tracking(1.6).foregroundStyle(lit ? Color.accent : Color.inkDim)
                .frame(minWidth: 84, minHeight: minTouch).contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
    }

    private func reload() {
        do {
            attached = try ledger.attached(to: ride.id)
            detached.removeAll { e in attached.contains { $0.id == e.id } }
            attachable = try ledger.attachable(to: ride).filter { e in !detached.contains { $0.id == e.id } }
            economy = try ledger.economy()
            drafts = try capture.pending().filter { $0.rideID == ride.id }
            bike = try garage.bike()
            error = nil
        } catch { self.error = "Couldn't load the ride: \(error.localizedDescription)" }
    }

    private func run(_ work: () throws -> Void) {
        do { try work(); reload() } catch { self.error = "Couldn't save: \(error.localizedDescription)" }
    }
}
