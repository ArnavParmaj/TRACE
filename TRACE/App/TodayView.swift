import SwiftData
import SwiftUI

/// S02 Today: 01 RIDE, 02 DRAFTS, 03 DUE. THIS WEEK and RECENT arrive with the data
/// behind them (M4, M7); they hide when empty anyway.
struct TodayView: View {
    @Environment(RideRecorder.self) private var recorder
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @State private var drafts: [CaptureDraft] = []
    @State private var due: [(label: String, status: DueStatus)] = []
    @State private var completing: CaptureDraft?
    @State private var showRide = false
    @State private var error: String?

    private var capture: Capture { Capture(context: context, user: LocalStubUser.load()) }
    private var garage: Garage { Garage(context: context, user: LocalStubUser.load()) }

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
                if let error {
                    Text(error).font(.condensed(13)).foregroundStyle(Color.alarmInk)
                }
            }
            .padding(20)
            .animation(.easeOut(duration: 0.2), value: drafts.count + due.count)
        }
        .task(id: scenePhase) { if scenePhase == .active { reload() } }
        .onReceive(NotificationCenter.default.publisher(for: .draftCaptured)) { _ in reload() }
        .sheet(item: $completing, onDismiss: reload) { DraftSheet(start: $0, capture: capture) }
        .fullScreenCover(isPresented: $showRide) { rideScreen }
        // START has no press haptic; the outcome is the confirmation (decision 52).
        .sensoryFeedback(.success, trigger: recorder.phase) { old, new in old == .idle && new == .recording && !showRide }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("TRACE").font(.oswald(28, .bold, relativeTo: .largeTitle)).tracking(1.6)
            Spacer()
            Text(Date.now.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)).uppercased())
                .font(.oswald(13, .medium)).tracking(2).foregroundStyle(Color.inkMuted)
        }
        .foregroundStyle(Color.ink)
    }

    // MARK: 01 RIDE

    @ViewBuilder private var rideSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHead(number: "01", title: "RIDE")
            if recorder.orphan != nil {
                rideRow("UNFINISHED RIDE", detail: "RESOLVE ›")
            } else if recorder.phase == .idle {
                CaptureButton(title: "START RIDE") {
                    // No bike added yet: the ride still records, against no vehicle.
                    recorder.start(vehicleID: (try? garage.bike())?.id ?? .unowned)
                }
                if drafts.isEmpty {
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

    /// shortcut: the M2 recorder screen stands in for Ride mode (S03) until M6.
    private var rideScreen: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button { showRide = false } label: {
                    Text("CLOSE").font(.oswald(15, .semibold)).tracking(1.5).foregroundStyle(Color.inkDim)
                        .frame(minWidth: minTouch, minHeight: minTouch)
                }
                .buttonStyle(PressStyle())
            }
            .padding(.horizontal, 12)
            RecorderDebugView()
        }
        .background(Color.ground.ignoresSafeArea())
        .environment(recorder)
    }

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

    private func reload() {
        do {
            drafts = try capture.pending()
            due = try garage.dueItems()
            error = nil
        } catch { self.error = "Couldn't load Today: \(error.localizedDescription)" }
        Reminders.refresh(garage)   // dates move on; re-plan whenever the app comes back
    }
}

/// "01 RIDE ──────── 2" section label.
struct SectionHead: View {
    let number: String
    let title: String
    var count: Int?

    var body: some View {
        HStack(spacing: 10) {
            Text("\(number) \(title)").font(.oswald(13, .medium)).tracking(2).foregroundStyle(Color.inkMuted)
            Rectangle().fill(Color.surfaceRule).frame(height: 1)
            if let count {
                Text("\(count)").font(.oswald(13, .medium)).foregroundStyle(Color.inkMuted)
            }
        }
        .accessibilityAddTraits(.isHeader)
    }
}

/// The 106pt capture button (DESIGN.md): black fill, amber border, amber spine.
struct CaptureButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.oswald(28, .bold)).tracking(1.6).foregroundStyle(Color.ink)
                .frame(maxWidth: .infinity, minHeight: 106, alignment: .leading)
                .padding(.leading, 28)
                .overlay { Rectangle().stroke(Color.accent, lineWidth: 2) }
                .overlay(alignment: .leading) { Rectangle().fill(Color.accent).frame(width: 10) }
                .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle(haptic: false))
    }
}
