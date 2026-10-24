import Charts
import SwiftData
import SwiftUI

/// S10 Money: the period total, spend by category, km/L over time, and every entry.
struct MoneyView: View {
    enum Period: String, CaseIterable {
        case week, month, year
        var component: Calendar.Component { self == .week ? .weekOfYear : self == .month ? .month : .year }

        /// "19–25 OCT", "OCTOBER", "2026 SO FAR".
        func caption(_ span: DateInterval) -> String {
            switch self {
            case .week:
                let end = span.end.addingTimeInterval(-1)
                return "\(span.start.formatted(.dateTime.day()))–\(end.formatted(.dateTime.day().month(.abbreviated)))".uppercased()
            case .month: return span.start.formatted(.dateTime.month(.wide)).uppercased()
            case .year: return span.start.formatted(.dateTime.year()) + " SO FAR"
            }
        }
    }

    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @State private var period = Period.month
    @State private var entries: [Expense] = []
    @State private var economy: [Economy] = []
    @State private var rides: [UUID: Ride] = [:]
    @State private var anyEver = false
    @State private var caption = ""
    @State private var partials = 0
    @State private var months: [(month: Date, minor: Int)] = []
    @State private var editing: Expense?
    @State private var adding = false
    @State private var openRide: Ride?
    @State private var error: String?

    private var ledger: Ledger { Ledger(context: context, user: LocalStubUser.load()) }
    private var capture: Capture { Capture(context: context, user: LocalStubUser.load()) }
    private var total: Int { entries.reduce(0) { $0 + $1.amountMinor } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 16) {
                    ScreenHeader(title: "MONEY") {
                        Text("ON THIS PHONE ONLY").font(.oswald(12, .medium)).tracking(1.7).foregroundStyle(Color.inkMuted)
                            .multilineTextAlignment(.trailing).fixedSize(horizontal: false, vertical: true)   // wraps at large sizes instead of clipping
                    }
                    periodPicker
                }
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(Money.format(total)).font(.oswald(48, .bold, relativeTo: .largeTitle))
                        .monospacedDigit().foregroundStyle(Color.ink).lineLimit(1).minimumScaleFactor(0.6)
                    Text(caption).font(.oswald(13, .medium)).tracking(1.6).foregroundStyle(Color.inkMuted)
                }
                if !anyEver {
                    Text("Nothing logged. Press the Action Button at your next fill.")
                        .font(.condensed(17)).foregroundStyle(Color.inkDim)
                }
                if !entries.isEmpty { byCategory }
                if anyEver { fuelEconomy }
                if anyEver { trend }
                if !entries.isEmpty { entryList }
                PrimaryButton("+ ADD EXPENSE") { adding = true }
                if let error { Text(error).font(.condensed(13)).foregroundStyle(Color.alarmInk) }
            }
            .padding(.horizontal, 20).padding(.bottom, 20)
            .animation(.easeOut(duration: 0.2), value: entries.map(\.id))
        }
        .task(id: period) { reload() }
        .task(id: scenePhase) { if scenePhase == .active { reload() } }
        .sheet(item: $editing, onDismiss: reload) { ExpenseSheet(expense: $0, capture: capture, ledger: ledger) }
        .sheet(isPresented: $adding, onDismiss: reload) { ExpenseSheet(expense: nil, capture: capture, ledger: ledger) }
        .sheet(item: $openRide, onDismiss: reload) { RideSheet(ride: $0) }
    }

    /// Three equal cells; the chosen one gets an amber underline, not a fill.
    private var periodPicker: some View {
        HStack(spacing: 0) {
            ForEach(Period.allCases, id: \.self) { p in
                let on = p == period
                Button { period = p } label: {
                    Text(p.rawValue.uppercased()).font(.oswald(15, .medium)).tracking(2.4)
                        .foregroundStyle(on ? Color.ink : Color.inkMuted)
                        .frame(maxWidth: .infinity, minHeight: minTouch)
                        .overlay(alignment: .bottom) { Rectangle().fill(on ? Color.accent : .clear).frame(height: 2) }
                        .contentShape(Rectangle())
                }
                .buttonStyle(PressStyle())
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .overlay { Rectangle().stroke(Color.surfaceRule, lineWidth: 1) }
    }

    // MARK: 01 BY CATEGORY

    private var byCategory: some View {
        let sums = ExpenseCategory.allCases
            .map { c in (c, entries.filter { $0.category == c }.reduce(0) { $0 + $1.amountMinor }) }
            .filter { $0.1 > 0 }
            .sorted { $0.1 > $1.1 }
        let top = max(1, sums.first?.1 ?? 1)
        return VStack(alignment: .leading, spacing: 12) {
            SectionHead(number: "01", title: "BY CATEGORY")
            ForEach(sums, id: \.0) { c, minor in
                HStack(spacing: 10) {
                    Text(c.rawValue.uppercased()).font(.oswald(14, .medium)).tracking(1.7).foregroundStyle(Color.inkDim)
                        .frame(width: 76, alignment: .leading)
                    Rectangle().fill(Color.surfaceLine).frame(height: 6)
                        .overlay(alignment: .leading) {
                            GeometryReader { g in
                                Rectangle().fill(Color.inkDim).frame(width: g.size.width * CGFloat(minor) / CGFloat(top))
                            }
                        }
                    Text(Money.format(minor)).font(.oswald(16, .semibold)).monospacedDigit().foregroundStyle(Color.ink)
                        .fixedSize()
                }
                .accessibilityElement(children: .combine)
            }
        }
    }

    // MARK: 02 FUEL ECONOMY (all time: one week rarely holds two fills)

    private var fuelEconomy: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHead(number: "02", title: "FUEL ECONOMY")
            if economy.count >= 2 {
                Chart {
                    ForEach(economy, id: \.closingID) { e in
                        LineMark(x: .value("Date", e.at), y: .value("km/L", e.kmPerL))
                            .foregroundStyle(Color.inkDim).lineStyle(StrokeStyle(lineWidth: 2))
                    }
                    if let last = economy.last {   // the latest fill is the lit point
                        PointMark(x: .value("Date", last.at), y: .value("km/L", last.kmPerL))
                            .symbol { Circle().strokeBorder(Color.accent, lineWidth: 2).background(Circle().fill(Color.ground)).frame(width: 12, height: 12) }
                    }
                }
                .chartYScale(domain: .automatic(includesZero: false))
                .chartXAxis { AxisMarks { _ in AxisValueLabel().foregroundStyle(Color.inkMuted) } }
                .chartYAxis {
                    AxisMarks { _ in
                        AxisGridLine().foregroundStyle(Color.surfaceLine)
                        AxisValueLabel().foregroundStyle(Color.inkMuted)
                    }
                }
                .frame(height: 120)
                .accessibilityLabel("Kilometres per litre over \(economy.count) full-tank intervals")
            }
            if let latest = economy.last {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(String(format: "%.1f KM/L", latest.kmPerL)).font(.oswald(20, .semibold)).monospacedDigit()
                        .foregroundStyle(Color.ink)
                    Text(partials == 0 ? "LATEST" : "LATEST · \(partials) PARTIAL \(partials == 1 ? "FILL" : "FILLS") EXCLUDED")
                        .font(.oswald(13, .medium)).tracking(1).foregroundStyle(Color.inkMuted)
                }
            } else {
                // W6: never 0.0 and never a guess.
                Text("— KM/L").font(.oswald(26, .semibold)).foregroundStyle(Color.ink)
                Text("needs two full-tank fills in a row, with odometer").font(.condensed(15)).foregroundStyle(Color.inkDim)
            }
        }
    }

    // MARK: 03 TREND

    private var trend: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHead(number: "03", title: "6 MONTHS")
            Chart(months, id: \.month) { m in
                BarMark(x: .value("Month", m.month, unit: .month), y: .value("₹", Double(m.minor) / 100))
                    .foregroundStyle(m.month == months.last?.month ? Color.accent : Color.inkDim)
            }
            .chartXAxis { AxisMarks(values: .stride(by: .month)) { _ in
                AxisValueLabel(format: .dateTime.month(.narrow)).foregroundStyle(Color.inkMuted) } }
            .chartYAxis { AxisMarks(values: .automatic(desiredCount: 3)) { _ in
                AxisGridLine().foregroundStyle(Color.surfaceLine)
                AxisValueLabel().foregroundStyle(Color.inkMuted) } }
            .frame(height: 110)
            .accessibilityLabel("Spending per month for six months")
        }
    }

    /// Paise per calendar month, the last six ending this month, oldest first.
    static func monthly(_ all: [Expense], now: Date = .now) -> [(month: Date, minor: Int)] {
        let cal = Calendar(identifier: .iso8601)
        guard let this = cal.dateInterval(of: .month, for: now)?.start else { return [] }
        let starts = (0..<6).reversed().compactMap { cal.date(byAdding: .month, value: -$0, to: this) }
        var sums = [Date: Int]()
        for e in all { if let m = cal.dateInterval(of: .month, for: e.occurredAt)?.start { sums[m, default: 0] += e.amountMinor } }
        return starts.map { ($0, sums[$0] ?? 0) }
    }

    // MARK: 04 ENTRIES

    private var entryList: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHead(number: "04", title: "ENTRIES", count: entries.count).padding(.bottom, 4)
            ForEach(entries) { e in
                VStack(alignment: .leading, spacing: 0) {
                    Button { editing = e } label: { ExpenseRow(expense: e, showsDay: true) }.buttonStyle(PressStyle())
                    if let id = e.rideID, let ride = rides[id] {
                        Button { openRide = ride } label: {
                            Text("· \(ride.displayName) ›").font(.condensed(15)).foregroundStyle(Color.accent)
                                .lineLimit(2).frame(maxWidth: .infinity, minHeight: minTouch, alignment: .leading)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(PressStyle())
                    }
                }
            }
        }
    }

    private func reload() {
        do {
            let all = try ledger.all()
            let span = Calendar(identifier: .iso8601).dateInterval(of: period.component, for: .now) ?? DateInterval()
            entries = all.filter { span.contains($0.occurredAt) }
            caption = period.caption(span)
            partials = all.filter { $0.category == .fuel && $0.isFullTank == false }.count
            months = Self.monthly(all)
            anyEver = !all.isEmpty
            economy = Ledger.economy(all)
            rides = [:]
            for id in Set(entries.compactMap(\.rideID)) { rides[id] = try ledger.ride(id) }
            error = nil
        } catch { self.error = "Couldn't load MONEY: \(error.localizedDescription)" }
    }
}

/// One expense: [day] category, fuel detail or note, amount. Amounts never truncate (W2).
struct ExpenseRow: View {
    let expense: Expense
    var showsDay = false

    var body: some View {
        HStack(spacing: 12) {
            if showsDay {
                Text(expense.occurredAt.formatted(.dateTime.weekday(.abbreviated).day()).uppercased())
                    .font(.oswald(13, .medium)).tracking(1.5).foregroundStyle(Color.inkMuted)
                    .frame(width: 52, alignment: .leading)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(expense.category.rawValue.capitalized).font(.oswald(17, .medium)).foregroundStyle(Color.ink)
                if let detail { Text(detail).font(.condensed(15)).foregroundStyle(Color.inkDim).lineLimit(1) }
            }
            Spacer(minLength: 8)
            Text(Money.format(expense.amountMinor, currencyCode: expense.currencyCode))
                .font(.oswald(20, .medium)).monospacedDigit().foregroundStyle(Color.ink).fixedSize()
        }
        .frame(maxWidth: .infinity, minHeight: minTouch, alignment: .leading)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.surfaceLine).frame(height: 1) }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private var detail: String? { expense.detailLine }
}

extension Expense {
    /// "4.1 L · FULL · note": what a row shows under the category.
    var detailLine: String? {
        let expense = self
        var parts: [String] = []
        if expense.category == .fuel {
            if let l = expense.litres { parts.append(String(format: "%g L", l)) }
            if let full = expense.isFullTank { parts.append(full ? "FULL" : "PARTIAL") }
        }
        if let note = expense.note { parts.append(note) }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}
