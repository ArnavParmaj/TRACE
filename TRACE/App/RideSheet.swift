import SwiftData
import SwiftUI

extension Ride {
    /// The rider's name for the ride, else its start date.
    var displayName: String {
        title ?? startedAt.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)).uppercased()
    }
}

/// S05 recap, shown once when a ride stops, and the cost part of S07 when opened from RIDES.
/// shortcut: S07's map, elevation and splits are M7; until then this sheet is the ride detail.
struct RideSheet: View {
    let ride: Ride
    var isRecap = false

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var attached: [Expense] = []
    @State private var attachable: [Expense] = []
    @State private var drafts: [CaptureDraft] = []
    @State private var economy: [Economy] = []
    @State private var bike: Vehicle?
    @State private var picking = false
    @State private var editing: Expense?
    @State private var completing: CaptureDraft?
    @State private var odometer = false
    @State private var error: String?

    private var ledger: Ledger { Ledger(context: context, user: LocalStubUser.load()) }
    private var capture: Capture { Capture(context: context, user: LocalStubUser.load()) }
    private var garage: Garage { Garage(context: context, user: LocalStubUser.load()) }
    private var totalMinor: Int { attached.reduce(0) { $0 + $1.amountMinor } }

    var body: some View {
        VStack(spacing: 0) {
            SheetBar(title: isRecap ? "RIDE DONE" : "RIDE")
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    headline
                    cost
                    if !drafts.isEmpty { draftLine }
                    if isRecap, let bike { odometerPrompt(bike) }
                    if let error { Text(error).font(.condensed(13)).foregroundStyle(Color.alarmInk) }
                }
                .padding(20)
                .animation(.easeOut(duration: 0.2), value: attached.map(\.id) + attachable.map(\.id))
            }
            if isRecap {
                PrimaryButton("DONE") { dismiss() }.padding(.horizontal, 20).padding(.vertical, 12)
            }
        }
        .background(Color.ground.ignoresSafeArea())
        .presentationBackground(Color.ground)
        .task { reload() }
        .sheet(item: $editing, onDismiss: reload) { ExpenseSheet(expense: $0, capture: capture, ledger: ledger) }
        .sheet(item: $completing, onDismiss: reload) { DraftSheet(start: $0, capture: capture, ledger: ledger) }
        .sheet(isPresented: $odometer, onDismiss: reload) { if let bike { OdometerSheet(bike: bike, garage: garage) } }
    }

    private var headline: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(ride.displayName).font(.oswald(28, .bold, relativeTo: .largeTitle)).foregroundStyle(Color.ink)
            if ride.title != nil {
                Text(ride.startedAt.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).hour().minute()))
                    .font(.oswald(13, .medium)).tracking(2).textCase(.uppercase).foregroundStyle(Color.inkMuted)
            }
            HStack(alignment: .firstTextBaseline, spacing: 18) {
                StatCell(value: String(format: "%.1f", Double(ride.distanceM) / 1000), unit: "KM")
                StatCell(value: StatCell.clock(ride.movingDurationS), unit: "MOVING")
                StatCell(value: "+\(ride.climbM)", unit: "CLIMB M")
                StatCell(value: Money.format(totalMinor), unit: "SPENT")
            }
        }
    }

    // MARK: 04 COST

    private var cost: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHead(number: "04", title: "COST").padding(.bottom, 4)
            if attached.isEmpty {
                Text("Nothing attached to this ride.").font(.condensed(15)).foregroundStyle(Color.inkDim)
                    .frame(minHeight: minTouch, alignment: .leading)
            }
            ForEach(attached) { e in
                HStack(spacing: 8) {
                    Button { editing = e } label: { ExpenseRow(expense: e) }.buttonStyle(PressStyle())
                    smallButton("DETACH") { run { try ledger.detach(e) } }
                }
            }
            Button { picking.toggle() } label: {
                Text(picking ? "− HIDE" : "+ ATTACH AN EXPENSE").font(.oswald(15, .semibold)).tracking(1.5)
                    .foregroundStyle(Color.accent)
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
                        smallButton("ATTACH") { run { try ledger.attach(e, to: ride) } }
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
        return VStack(alignment: .leading, spacing: 2) {
            Text(here.map { String(format: "%.1f KM/L", $0.kmPerL) } ?? "— KM/L")
                .font(.oswald(22, .medium)).monospacedDigit().foregroundStyle(Color.ink)
            Text(here == nil ? "needs two full-tank fills in a row, with odometer" : "full tank to full tank")
                .font(.condensed(15)).foregroundStyle(Color.inkDim)
        }
        .padding(.top, 8)
    }

    private var draftLine: some View {
        Button { completing = drafts.first } label: {
            HStack {
                Text(drafts.count == 1 ? "1 draft from this ride" : "\(drafts.count) drafts from this ride")
                    .font(.condensed(17)).foregroundStyle(Color.ink)
                Spacer()
                Text("COMPLETE ›").font(.oswald(15, .semibold)).tracking(1.5).foregroundStyle(Color.accent)
            }
            .frame(minHeight: minTouch).contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
    }

    /// Skippable: manual is authoritative, GPS only suggests (decision 24).
    private func odometerPrompt(_ bike: Vehicle) -> some View {
        let suggested = (try? garage.odometerSuggestion(bike)) ?? bike.odometerKm
        return Button { odometer = true } label: {
            HStack {
                Text("Odometer now? Suggested \(suggested.formatted())").font(.condensed(17)).foregroundStyle(Color.ink)
                Spacer()
                Text("UPDATE ›").font(.oswald(15, .semibold)).tracking(1.5).foregroundStyle(Color.accent)
            }
            .frame(minHeight: minTouch).contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
    }

    private func smallButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.oswald(15, .semibold)).tracking(1.5).foregroundStyle(Color.accent)
                .frame(minWidth: 84, minHeight: minTouch).contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
    }

    private func reload() {
        do {
            attached = try ledger.attached(to: ride.id)
            attachable = try ledger.attachable(to: ride)
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
