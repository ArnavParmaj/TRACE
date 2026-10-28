import SwiftUI

/// S03 Ride mode (artboard F): the handlebar screen. Lights few pixels, no precision targets.
/// Tap anywhere above the band logs a draft; hold the band 2 s to stop. An unfinished ride
/// found on launch is resolved here first (S04).
struct RideModeView: View {
    @Environment(RideRecorder.self) private var recorder
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var logged = 0
    @State private var flash = false
    @State private var holding = false
    @State private var hold: CGFloat = 0
    @State private var stops = 0
    @State private var failed = false
    @State private var locationOff = false
    @Environment(\.scenePhase) private var scenePhase

    /// Above this the gauge is full. A scale, not a limit.
    static let gaugeMaxKph = 120.0

    var body: some View {
        VStack(spacing: 0) {
            if let orphan = recorder.orphan { RecoveryView(ride: orphan) } else { riding }
        }
        .background(Color.ground.ignoresSafeArea())
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }    // readable on the bars
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
        .task(id: scenePhase) { locationOff = LocationService.isDenied }   // rechecked on return from Settings
        // Haptic and visual on the same frame (decision 52).
        .sensoryFeedback(.success, trigger: logged)
        .sensoryFeedback(.success, trigger: stops)
        .sensoryFeedback(.impact(weight: .light), trigger: holding) { _, now in now }
        .sensoryFeedback(trigger: recorder.phase) { old, new in
            switch (old, new) {
            case (.recording, .paused): .impact(weight: .heavy)
            case (.paused, .recording): .success
            default: nil
            }
        }
    }

    // MARK: Riding

    private var riding: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            VStack(spacing: 0) {
                topBar(now: context.date)
                Button(action: log) { centre(now: context.date) }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Log a draft")
                    .accessibilityHint("Saves the time and place. Complete it later on Today.")
                stopBand
            }
        }
    }

    private func topBar(now: Date) -> some View {
        let paused = recorder.phase == .paused
        return HStack(spacing: 8) {
            Button { dismiss() } label: {
                Text("‹").font(.oswald(30, .medium)).foregroundStyle(Color.inkMuted)
                    .frame(width: minTouch, height: minTouch).contentShape(Rectangle())
            }
            .buttonStyle(PressStyle())
            .accessibilityLabel("Back to Today. The ride keeps recording.")
            Circle().fill(flash ? Color.ink : Color.accent).frame(width: 10, height: 10)
                .opacity(paused ? 0.4 : 1)
            Text(paused ? "PAUSED" : "REC").font(.oswald(13, .medium)).tracking(2.6).foregroundStyle(Color.inkMuted)
            Spacer()
            Text(clock(recorder.elapsed(at: now))).font(.oswald(17, .medium)).monospacedDigit().foregroundStyle(Color.inkMuted)
            Button { paused ? recorder.resumeFromPause() : recorder.pause() } label: {
                Text(paused ? "RESUME" : "PAUSE").font(.oswald(14, .semibold)).tracking(1.6)
                    .foregroundStyle(paused ? Color.accent : Color.inkDim)
                    .frame(minWidth: 84, minHeight: minTouch).contentShape(Rectangle())
            }
            .buttonStyle(PressStyle(haptic: false))
        }
        .padding(.trailing, 8)
    }

    private func centre(now: Date) -> some View {
        let speed = currentKph(now)
        return VStack(spacing: 18) {
            Spacer(minLength: 0)
            ZStack {
                Gauge(fraction: (speed ?? 0) / Self.gaugeMaxKph)
                VStack(spacing: 6) {
                    Text(speed.map { String(Int($0.rounded())) } ?? "--")
                        .font(.oswald(120, .bold)).monospacedDigit().tracking(-2)
                        .foregroundStyle(speed == nil ? Color.inkFaint : Color.ink)
                        .lineLimit(1).minimumScaleFactor(0.5)
                    Text(statusLabel(speed)).font(.oswald(15, .medium)).tracking(3.6).foregroundStyle(Color.inkMuted)
                }
                .padding(.top, 12)
            }
            .frame(width: 300, height: 264)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(speed.map { "Speed \(Int($0)) kilometres per hour" } ?? statusLabel(nil))
            HStack(spacing: 40) {
                stat(String(format: "%.1f", recorder.stats.distanceM / 1000), "KM")
                stat("+\(Int(recorder.stats.climbM))", "M CLIMB")
            }
            Text(failed ? "COULDN'T SAVE · TAP AGAIN" : flash ? "DRAFT LOGGED · \(logged)" : "TAP ANYWHERE TO LOG")
                .font(.oswald(15, .medium)).tracking(2.7)
                .foregroundStyle(failed ? Color.alarmInk : flash ? Color.accent : Color.inkMuted)
                .accessibilityHidden(true)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
    }

    private func stat(_ value: String, _ unit: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.oswald(40, .semibold)).monospacedDigit().foregroundStyle(Color.ink)
            Text(unit).font(.oswald(13, .medium)).tracking(2.6).foregroundStyle(Color.inkMuted)
        }
        .accessibilityElement(children: .combine)
    }

    /// Hold 2 s to stop; release early and it snaps back. No tap-to-stop, ever (S03).
    private var stopBand: some View {
        ZStack(alignment: .top) {
            Rectangle().fill(Color.accent).frame(height: 4)
                .scaleEffect(x: hold, anchor: .leading)
            Text(holding ? "KEEP HOLDING" : "HOLD TO STOP")
                .font(.oswald(18, .medium)).tracking(4).foregroundStyle(Color.inkDim)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(height: 116)
        .overlay(alignment: .top) { Rectangle().fill(Color.surfaceRule).frame(height: 1) }
        .contentShape(Rectangle())
        .onLongPressGesture(minimumDuration: 2, maximumDistance: 60) {
            stops += 1
            recorder.stop()
        } onPressingChanged: { pressing in
            holding = pressing
            if pressing {
                withAnimation(.linear(duration: 2)) { hold = 1 }
            } else {
                withAnimation(.easeOut(duration: 0.2)) { hold = 0 }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Stop ride")
        .accessibilityHint("Hold for two seconds.")
        .accessibilityAction { stops += 1; recorder.stop() }
    }

    // MARK: Actions

    private func log() {
        let fix = recorder.lastFix
        do {
            try Capture(context: context, user: LocalStubUser.load()).log(lat: fix?.lat, lon: fix?.lon)
            logged += 1
            failed = false
            flash = true
            let n = logged
            Task {
                try? await Task.sleep(for: .seconds(1))
                if logged == n { flash = false }
            }
        } catch {
            // Capture never blocks (invariant 7), but a lost draft must not look saved.
            flash = false
            failed = true
        }
    }

    // MARK: Values

    /// Nil when there's no recent fix: shown as "--", never as 0.
    private func currentKph(_ now: Date) -> Double? {
        guard recorder.phase == .recording, let fix = recorder.lastFix,
              now.timeIntervalSince(fix.time) < 10, fix.speedMps >= 0 else { return nil }
        return fix.speedMps * 3.6
    }

    private func statusLabel(_ speed: Double?) -> String {
        if recorder.phase == .paused { return "PAUSED" }
        if speed == nil && locationOff { return "LOCATION OFF" }   // Settings › TRACE › Location
        return speed == nil ? "NO GPS" : "KM/H"
    }

    private func clock(_ seconds: TimeInterval) -> String {
        let s = Int(seconds)
        return String(format: "%02d:%02d:%02d", s / 3600, s / 60 % 60, s % 60)
    }
}

/// 4pt stroked arc over 270°, unlit track, three ticks. Never filled (DESIGN.md).
private struct Gauge: View {
    let fraction: Double

    var body: some View {
        ZStack {
            arc.trim(from: 0, to: 0.75).stroke(Color.surfaceLine, lineWidth: 4)
            arc.trim(from: 0, to: 0.75 * min(1, max(0, fraction))).stroke(Color.accent, lineWidth: 4)
            ForEach([0.0, 0.375, 0.75], id: \.self) { at in
                Rectangle().fill(Color.inkFaint).frame(width: 2, height: 8)
                    .offset(y: -128)
                    .rotationEffect(.degrees(225 + at * 360))
            }
        }
        .frame(width: 240, height: 240)
        .accessibilityHidden(true)
    }

    /// Starts bottom-left, runs clockwise over the top.
    private var arc: some Shape { Circle().rotation(.degrees(135)) }
}

/// S04: a ride from before a kill or crash. Never auto-discarded (decision 25).
private struct RecoveryView: View {
    let ride: Ride
    @Environment(RideRecorder.self) private var recorder

    var body: some View {
        let savedUpTo = ride.updatedAt.formatted(date: .omitted, time: .shortened)
        let endsAt = (ride.pausedAt ?? ride.updatedAt).formatted(date: .omitted, time: .shortened)
        VStack(alignment: .leading, spacing: 14) {
            Hatch().frame(maxHeight: .infinity).padding(.horizontal, -20)
            Text("RIDE DIDN'T FINISH").font(.oswald(13, .medium)).tracking(2.6).foregroundStyle(Color.accent)
            Text("A ride from \(ride.startedAt.formatted(date: .omitted, time: .shortened)) is still open")
                .font(.oswald(30, .bold, relativeTo: .title)).foregroundStyle(Color.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text("The app was closed while recording. \(String(format: "%.1f", Double(ride.distanceM) / 1000)) km saved up to \(savedUpTo).")
                .font(.condensed(16)).foregroundStyle(Color.inkDim).fixedSize(horizontal: false, vertical: true)
            CaptureButton(title: "RESUME RIDE", subtitle: "Keep recording into the same ride") { recorder.resume() }
            Button { recorder.endOrphan() } label: {
                Text("END IT AT \(endsAt)").font(.oswald(17, .semibold)).tracking(1.8).foregroundStyle(Color.inkDim)
                    .frame(maxWidth: .infinity, minHeight: 64)
                    .overlay { Rectangle().stroke(Color.surfaceRule, lineWidth: 1) }
                    .contentShape(Rectangle())
            }
            .buttonStyle(PressStyle(haptic: false))
            Text("Nothing is thrown away. To delete the ride, open it from Rides.")
                .font(.condensed(14)).foregroundStyle(Color.inkMuted)
        }
        .padding(.horizontal, 20).padding(.bottom, 20)
        .sensoryFeedback(.success, trigger: recorder.orphan == nil) { _, resolved in resolved }
    }
}
