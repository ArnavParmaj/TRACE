import SwiftUI

/// List of finished rides; tap one for its cost, hold to rename or delete.
/// shortcut: M2 stand-in for S06; M7 replaces it with the real Rides screen (map, detail, trends).
struct RidesListView: View {
    @Environment(RideRecorder.self) private var recorder
    @Environment(\.modelContext) private var context
    @State private var rides: [Ride] = []
    @State private var totals: [UUID: Int] = [:]
    @State private var open: Ride?
    @State private var deleting: Ride?
    @State private var renaming: Ride?
    @State private var newName = ""

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ScreenHeader(title: "RIDES").padding(.bottom, 12)
                if rides.isEmpty {
                    Text("No finished rides yet. Start one on TODAY.")
                        .font(.condensed(17)).foregroundStyle(Color.inkDim)
                        .padding(.top, 8)
                }
                ForEach(rides) { ride in
                    row(ride)
                        .onTapGesture { open = ride }
                        .contextMenu {
                            Button("Rename ride") { newName = ride.title ?? ""; renaming = ride }
                            Button("Delete ride") { deleting = ride }
                        }
                }
                if !rides.isEmpty {
                    Text("Tap a ride for its cost. Hold to rename or delete it.").font(.condensed(13)).foregroundStyle(Color.inkFaint)
                        .padding(.top, 12)
                }
            }
            .padding(.horizontal, 20).padding(.bottom, 20)
        }
        // Reload on open and whenever a ride starts or ends while this tab is showing.
        .task(id: recorder.phase) { reload() }
        .sheet(item: $open, onDismiss: reload) { RideSheet(ride: $0) }
        .animation(.easeOut(duration: 0.2), value: rides.map(\.id))
        .alert("Delete this ride?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })) {
            Button("Delete") {
                if let deleting { recorder.delete(deleting) }
                reload()
            }
            Button("Cancel", role: .cancel) {}
        } message: { Text("Its route and stats are removed from TRACE.") }
        .alert("Name this ride", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
            TextField("Lonavala chai run", text: $newName)
            Button("Save") {
                if let renaming { recorder.rename(renaming, to: newName) }
                reload()
            }
            Button("Cancel", role: .cancel) {}
        } message: { Text("Leave it blank to show the date.") }
    }

    private func row(_ ride: Ride) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(ride.startedAt.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).hour().minute()))
                .font(.oswald(13, .medium)).tracking(2).textCase(.uppercase)
                .foregroundStyle(Color.inkMuted)
            if let title = ride.title {
                Text(title).font(.oswald(20, .semibold)).foregroundStyle(Color.ink).lineLimit(2)
            }
            HStack(alignment: .firstTextBaseline, spacing: 16) {
                StatCell(value: String(format: "%.2f", Double(ride.distanceM) / 1000), unit: "KM")
                StatCell(value: StatCell.clock(ride.elapsedDurationS), unit: "TOTAL")
                StatCell(value: StatCell.clock(ride.movingDurationS), unit: "MOVING")
                StatCell(value: String(format: "%.0f", ride.avgSpeedKph), unit: "AVG")
                StatCell(value: String(format: "%.0f", ride.maxSpeedKph), unit: "MAX")
            }
            if let spent = totals[ride.id] {
                Text(Money.format(spent) + " SPENT").font(.oswald(15, .medium)).monospacedDigit()
                    .foregroundStyle(Color.inkDim)
            }
        }
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.surfaceLine).frame(height: 1) }
        .background(Color.ground)              // the lift preview shows the row, not a hole
        .contentShape(Rectangle())             // hold anywhere in the row, not just on the text
        .accessibilityElement(children: .combine)
    }

    private func reload() {
        rides = recorder.finishedRides()
        totals = (try? Ledger(context: context, user: LocalStubUser.load()).totalsByRide()) ?? [:]
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
