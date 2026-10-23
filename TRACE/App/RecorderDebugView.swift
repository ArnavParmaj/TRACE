import SwiftUI

/// M2 debug screen: start / pause / stop, live numbers, and force-kill recovery (S04, decision 25).
/// shortcut: debug UI, opened from the Today ride row; Ride mode (S03) replaces it in M6.
struct RecorderDebugView: View {
    @Environment(RideRecorder.self) private var recorder
    @State private var confirmStop = false

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            if let orphan = recorder.orphan { recovery(orphan) }
            numbers
            Spacer(minLength: 0)
            if let error = recorder.lastError {
                Text(error).font(.condensed(13)).foregroundStyle(Color.alarmInk).lineLimit(3)
            }
            if recorder.orphan == nil { controls }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .confirmationDialog("Stop this ride?", isPresented: $confirmStop, titleVisibility: .visible) {
            Button("Stop ride") { recorder.stop() }   // no destructive role: system red is reserved (invariant 9)
        }
        // Haptics fire on the outcome, the same frame the screen changes (decision 52).
        .sensoryFeedback(trigger: recorder.phase) { old, new in
            switch (old, new) {
            case (.recording, .paused): .impact(weight: .heavy)
            case (_, .recording), (_, .idle): .success   // start, resume, stop, auto-close
            default: nil
            }
        }
        .sensoryFeedback(.success, trigger: recorder.orphan == nil) { wasResolved, resolved in
            !wasResolved && resolved && recorder.phase == .idle   // END AT; RESUME is covered above
        }
        .sensoryFeedback(.warning, trigger: confirmStop) { _, asking in asking }
    }

    private func recovery(_ ride: Ride) -> some View {
        // Seconds shown: the M2 ride test compares this with the kill time (≤ 15 s).
        let savedUpTo = ride.updatedAt.formatted(date: .omitted, time: .standard)
        let endsAt = (ride.pausedAt ?? ride.updatedAt).formatted(date: .omitted, time: .standard)
        let what = ride.pausedAt == nil ? "A ride" : "A paused ride"
        return VStack(alignment: .leading, spacing: 14) {
            Text("\(what) from \(ride.startedAt.formatted(date: .omitted, time: .shortened)) didn't finish. \(km(ride.distanceM)) km saved up to \(savedUpTo).")
                .font(.condensed(17, .medium)).foregroundStyle(Color.ink)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 12) {
                button("RESUME", lit: true) { recorder.resume() }
                button("END AT \(endsAt)", lit: false) { recorder.endOrphan() }
            }
        }
        .padding(16)
        .overlay { Rectangle().stroke(Color.accent, lineWidth: 1) }
    }

    private var numbers: some View {
        let stats = recorder.stats
        let fix = recorder.lastFix
        let elapsed = recorder.ride.flatMap { r in fix.map { $0.time.timeIntervalSince(r.startedAt) } } ?? 0
        let state = switch recorder.phase {
        case .idle: "IDLE"
        case .paused: "PAUSED"
        case .recording: fix == nil ? "WAITING FOR GPS" : "RECORDING"
        }
        let rows: [(String, String)] = [
            ("STATE", state),
            ("DISTANCE", "\(km(Int(stats.distanceM))) km"),
            ("ELAPSED", clock(elapsed)),
            ("STOPPED", clock(stats.stoppedS)),
            ("PAUSED", clock(TimeInterval(recorder.ride?.pausedDurationS ?? 0))),
            ("SPEED", recorder.phase == .paused ? "—" : fix.map { $0.speedMps >= 0 ? String(format: "%.0f km/h", $0.speedMps * 3.6) : "—" } ?? "—"),
            ("MAX", String(format: "%.0f km/h", stats.maxSpeedMps * 3.6)),
            ("CLIMB", "\(Int(stats.climbM)) m"),
            ("GPS", fix.map { String(format: "±%.0f m", $0.accuracyM) } ?? "—"),
            ("SAMPLES", "\(recorder.sampleCount)"),
            ("STOPS", "\(recorder.stopCount)"),
            ("SAVED", recorder.lastSave?.formatted(date: .omitted, time: .standard) ?? "—"),
        ]
        return VStack(spacing: 0) {
            ForEach(rows, id: \.0) { label, value in
                HStack {
                    Text(label).font(.oswald(13, .medium)).tracking(2).foregroundStyle(Color.inkMuted)
                    Spacer()
                    Text(value).font(.oswald(20, .medium)).foregroundStyle(Color.ink).monospacedDigit()
                }
                .padding(.vertical, 7)
                .overlay(alignment: .bottom) { Rectangle().fill(Color.surfaceLine).frame(height: 1) }
            }
        }
    }

    /// Idle: START. Riding: PAUSE + STOP. Paused: RESUME + STOP. Stop always ends the ride.
    @ViewBuilder private var controls: some View {
        switch recorder.phase {
        case .idle:
            // shortcut: rides log against no vehicle until bike onboarding exists (M5).
            bigButton("START RIDE", spine: true) { recorder.start(vehicleID: .unowned) }
        case .recording, .paused:
            HStack(spacing: 12) {
                if recorder.phase == .recording {
                    bigButton("PAUSE", spine: false) { recorder.pause() }
                } else {
                    bigButton("RESUME", spine: true) { recorder.resumeFromPause() }
                }
                bigButton("STOP", spine: false) { confirmStop = true }   // never the inviting one
            }
        }
    }

    /// Capture-button styling (DESIGN.md): black fill, amber border, amber left spine on the
    /// primary action. No press haptic: the outcome haptic is the confirmation.
    private func bigButton(_ title: String, spine: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.oswald(28, .bold)).tracking(1.6).foregroundStyle(Color.ink)
                .frame(maxWidth: .infinity, minHeight: 106, alignment: .leading)
                .padding(.leading, 28)
                .overlay { Rectangle().stroke(Color.accent, lineWidth: 2) }
                .overlay(alignment: .leading) { if spine { Rectangle().fill(Color.accent).frame(width: 10) } }
                .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle(haptic: false))
    }

    private func button(_ title: String, lit: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.oswald(16, .semibold)).tracking(1.5)
                .foregroundStyle(lit ? Color.accent : Color.inkDim)
                .frame(maxWidth: .infinity, minHeight: minTouch)
                .overlay { Rectangle().stroke(lit ? Color.accent : Color.surfaceRule, lineWidth: lit ? 2 : 1) }
                .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle(haptic: false))
    }

    private func km(_ metres: Int) -> String { String(format: "%.2f", Double(metres) / 1000) }

    private func clock(_ seconds: TimeInterval) -> String {
        let s = Int(seconds)
        return String(format: "%d:%02d:%02d", s / 3600, s / 60 % 60, s % 60)
    }
}
