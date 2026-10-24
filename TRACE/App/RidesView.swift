import Charts
import SwiftUI

/// S06 Rides: distance per week (tap a bar to filter), personal bests, rides by month.
/// Tap a ride for S07; hold it to rename or delete.
struct RidesView: View {
    @Environment(RideRecorder.self) private var recorder
    @Environment(\.modelContext) private var context
    @State private var rides: [Ride] = []
    @State private var totals: [UUID: Int] = [:]
    @State private var bests = PersonalBests()
    @State private var weeks: [(week: Date, km: Double)] = []
    @State private var pickedWeek: Date?
    @State private var open: Ride?
    @State private var deleting: Ride?
    @State private var renaming: Ride?
    @State private var newName = ""

    private var review: Review { Review(context: context, user: LocalStubUser.load()) }
    private static let cal = Calendar(identifier: .iso8601)

    /// Rides shown: all, or the picked week's.
    private var shown: [Ride] {
        guard let w = pickedWeek, let span = Self.cal.dateInterval(of: .weekOfYear, for: w) else { return rides }
        return rides.filter { span.contains($0.startedAt) }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 28) {
                ScreenHeader(title: "RIDES")
                if rides.isEmpty {
                    Text("No rides yet. Start one from Today.").font(.condensed(17)).foregroundStyle(Color.inkDim)
                } else {
                    weekChart
                    bestsCard
                    list
                }
            }
            .padding(.horizontal, 20).padding(.bottom, 20)
        }
        // Reload on open and whenever a ride starts or ends while this tab is showing.
        .task(id: recorder.phase) {
            reload()
            try? review.fillFastest(rides)
            await review.fillPlaces(rides)   // offline: nothing happens, tried again next time
            reload()
        }
        .sheet(item: $open, onDismiss: reload) { RideSheet(ride: $0) }
        .animation(.easeOut(duration: 0.2), value: shown.map(\.id))
        .alert("Delete this ride?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })) {
            Button("Delete", role: .destructive) {
                if let deleting { recorder.delete(deleting) }
                reload()
            }
            Button("Cancel", role: .cancel) {}
        } message: { Text("Its route and stats are removed. Attached expenses stay in MONEY.") }
        .alert("Name this ride", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
            TextField("Lonavala chai run", text: $newName)
            Button("Save") {
                if let renaming { recorder.rename(renaming, to: newName) }
                reload()
            }
            Button("Cancel", role: .cancel) {}
        } message: { Text("Leave it blank to show the places or date.") }
    }

    // MARK: Distance per week

    private var weekChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHead(number: "01", title: "12 WEEKS",
                        value: String(format: "%.0f KM", weeks.reduce(0) { $0 + $1.km }))
            Chart(weeks, id: \.week) { w in
                BarMark(x: .value("Week", w.week, unit: .weekOfYear), y: .value("km", w.km))
                    .foregroundStyle(isPicked(w.week) ? Color.accent : Color.inkDim)
            }
            .chartXSelection(value: Binding(get: { pickedWeek }, set: { if let d = $0 { pick(d) } }))
            .chartXAxis { AxisMarks(values: .stride(by: .weekOfYear, count: 4)) { _ in
                AxisValueLabel(format: .dateTime.day().month(.abbreviated)).foregroundStyle(Color.inkMuted) } }
            .chartYAxis { AxisMarks(values: .automatic(desiredCount: 3)) { _ in
                AxisGridLine().foregroundStyle(Color.surfaceLine)
                AxisValueLabel().foregroundStyle(Color.inkMuted) } }
            .frame(height: 120)
            .accessibilityLabel("Distance per week for 12 weeks")
            if let w = pickedWeek {
                Button { pickedWeek = nil } label: {
                    HStack {
                        Text("WEEK OF \(w.formatted(.dateTime.day().month(.abbreviated)).uppercased())")
                            .font(.oswald(13, .medium)).tracking(1.6).foregroundStyle(Color.inkDim)
                        Spacer()
                        Text("SHOW ALL").font(.oswald(13, .medium)).tracking(1.6).foregroundStyle(Color.accent)
                    }
                    .frame(minHeight: minTouch).contentShape(Rectangle())
                }
                .buttonStyle(PressStyle())
            } else {
                Text("Tap a bar to see that week.").font(.condensed(13)).foregroundStyle(Color.inkMuted)
            }
        }
    }

    private func isPicked(_ week: Date) -> Bool {
        guard let p = pickedWeek else { return false }
        return Self.cal.isDate(p, equalTo: week, toGranularity: .weekOfYear)
    }

    private func pick(_ date: Date) {
        pickedWeek = isPicked(date) ? nil : Self.cal.dateInterval(of: .weekOfYear, for: date)?.start
    }

    // MARK: Personal bests

    private var bestsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHead(number: "02", title: "PERSONAL BESTS")
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 0), GridItem(.flexible())], spacing: 0) {
                best(bests.longest, bests.longest.map { String(format: "%.1f", Double($0.distanceM) / 1000) }, "LONGEST KM")
                best(bests.topSpeed, bests.topSpeed.map { String(format: "%.0f", $0.maxSpeedKph) }, "TOP KM/H")
                best(bests.biggestClimb, bests.biggestClimb.map { "+\($0.climbM)" }, "CLIMB M")
                best(bests.fastest10k, bests.fastest10k?.fastest10kS.map(StatCell.clock), "FASTEST 10 KM")
            }
            .overlay { Rectangle().stroke(Color.surfaceRule, lineWidth: 0.5) }
        }
    }

    private func best(_ ride: Ride?, _ value: String?, _ label: String) -> some View {
        Button { open = ride } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(value ?? "—").font(.oswald(26, .semibold)).monospacedDigit().foregroundStyle(Color.ink)
                    .lineLimit(1).minimumScaleFactor(0.6)
                Text(label).font(.oswald(12, .medium)).tracking(2).foregroundStyle(Color.inkMuted)
                    .lineLimit(1).minimumScaleFactor(0.6)
                Text(ride?.startedAt.formatted(.dateTime.day().month(.abbreviated)).uppercased() ?? "needs a 10 km ride")
                    .font(.condensed(13)).foregroundStyle(Color.inkMuted).lineLimit(1)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 96, alignment: .leading)
            .overlay { Rectangle().stroke(Color.surfaceRule, lineWidth: 0.5) }
            .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
        .disabled(ride == nil)
        .accessibilityElement(children: .combine)
    }

    // MARK: Rides by month

    private var list: some View {
        let groups = Dictionary(grouping: shown) { Self.cal.dateInterval(of: .month, for: $0.startedAt)?.start ?? $0.startedAt }
        let months = groups.keys.sorted(by: >)
        return VStack(alignment: .leading, spacing: 0) {
            SectionHead(number: "03", title: "RIDES", count: shown.count).padding(.bottom, 4)
            ForEach(months, id: \.self) { month in
                Text(month.formatted(.dateTime.month(.wide).year()).uppercased())
                    .font(.oswald(13, .medium)).tracking(2).foregroundStyle(Color.inkMuted)
                    .padding(.top, 16).padding(.bottom, 4)
                ForEach(groups[month] ?? []) { ride in
                    row(ride)
                        .onTapGesture { open = ride }
                        .contextMenu {
                            Button("Rename ride") { newName = ride.title ?? ""; renaming = ride }
                            Button("Delete ride", role: .destructive) { deleting = ride }
                        }
                }
            }
            Text("Tap a ride to open it. Hold to rename or delete.").font(.condensed(13)).foregroundStyle(Color.inkMuted)
                .padding(.top, 12)
        }
    }

    private func row(_ ride: Ride) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(ride.startedAt.formatted(.dateTime.weekday(.abbreviated).day()).uppercased())
                .font(.oswald(13, .medium)).tracking(1).foregroundStyle(Color.inkMuted).frame(width: 52, alignment: .leading)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(ride.displayName).font(.condensed(17)).foregroundStyle(Color.ink).lineLimit(2)
                }
                Text(String(format: "%.1f km · ", Double(ride.distanceM) / 1000) + StatCell.clock(ride.movingDurationS) + " moving")
                    .font(.condensed(13)).foregroundStyle(Color.inkMuted)
            }
            Spacer(minLength: 8)
            if let spent = totals[ride.id] {
                Text(Money.format(spent)).font(.oswald(17, .semibold)).monospacedDigit().foregroundStyle(Color.ink).fixedSize()
            }
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.surfaceLine).frame(height: 1) }
        .background(Color.ground)              // the lift preview shows the row, not a hole
        .contentShape(Rectangle())             // hold anywhere in the row, not just on the text
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens the ride")
    }

    private func reload() {
        rides = recorder.finishedRides()
        totals = (try? Ledger(context: context, user: LocalStubUser.load()).totalsByRide()) ?? [:]
        bests = Review.bests(rides)
        weeks = Review.weeklyKm(rides)
    }
}

/// Value over a small unit label: "86.4 / KM".
struct StatCell: View {
    let value: String
    let unit: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.oswald(22, .medium)).foregroundStyle(Color.ink).monospacedDigit()
                .lineLimit(1).minimumScaleFactor(0.7)
            Text(unit).font(.oswald(11, .medium)).tracking(1.5).foregroundStyle(Color.inkMuted)
        }
    }

    static func clock(_ seconds: Int) -> String {
        seconds >= 3600
            ? String(format: "%d:%02d:%02d", seconds / 3600, seconds / 60 % 60, seconds % 60)
            : String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}
