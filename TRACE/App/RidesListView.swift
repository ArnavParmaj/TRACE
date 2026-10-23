import SwiftUI

/// Read-only list of finished rides, so a ride can be checked after recording it.
/// shortcut: M2 stand-in for S06; M7 replaces it with the real Rides screen (map, detail, trends).
struct RidesListView: View {
    @Environment(RideRecorder.self) private var recorder
    @State private var rides: [Ride] = []
    @State private var deleting: Ride?

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                Text("RIDES")
                    .font(.oswald(28, .bold, relativeTo: .largeTitle)).tracking(1.6)
                    .foregroundStyle(Color.ink)
                    .padding(.bottom, 12)
                if rides.isEmpty {
                    Text("No finished rides yet. Start one on TODAY.")
                        .font(.condensed(17)).foregroundStyle(Color.inkDim)
                        .padding(.top, 8)
                }
                ForEach(rides) { ride in
                    row(ride)
                        .contextMenu { Button("Delete ride") { deleting = ride } }
                }
                if !rides.isEmpty {
                    Text("Hold a ride to delete it.").font(.condensed(13)).foregroundStyle(Color.inkFaint)
                        .padding(.top, 12)
                }
            }
            .padding(20)
        }
        // Reload on open and whenever a ride starts or ends while this tab is showing.
        .task(id: recorder.phase) { rides = recorder.finishedRides() }
        .animation(.easeOut(duration: 0.2), value: rides.map(\.id))
        .alert("Delete this ride?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })) {
            Button("Delete") {
                if let deleting { recorder.delete(deleting) }
                rides = recorder.finishedRides()
            }
            Button("Cancel", role: .cancel) {}
        } message: { Text("Its route and stats are removed from TRACE.") }
    }

    private func row(_ ride: Ride) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(ride.startedAt.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).hour().minute()))
                .font(.oswald(13, .medium)).tracking(2).textCase(.uppercase)
                .foregroundStyle(Color.inkMuted)
            HStack(alignment: .firstTextBaseline, spacing: 16) {
                stat(String(format: "%.2f", Double(ride.distanceM) / 1000), "KM")
                stat(clock(ride.elapsedDurationS), "TOTAL")
                stat(clock(ride.movingDurationS), "MOVING")
                stat(String(format: "%.0f", ride.avgSpeedKph), "AVG")
                stat(String(format: "%.0f", ride.maxSpeedKph), "MAX")
            }
        }
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.surfaceLine).frame(height: 1) }
        .accessibilityElement(children: .combine)
    }

    private func stat(_ value: String, _ unit: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.oswald(22, .medium)).foregroundStyle(Color.ink).monospacedDigit()
            Text(unit).font(.oswald(11, .medium)).tracking(1.5).foregroundStyle(Color.inkMuted)
        }
    }

    private func clock(_ seconds: Int) -> String {
        seconds >= 3600
            ? String(format: "%d:%02d:%02d", seconds / 3600, seconds / 60 % 60, seconds % 60)
            : String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}
