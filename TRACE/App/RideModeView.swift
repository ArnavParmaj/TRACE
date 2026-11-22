import SwiftUI

/// S03 Ride mode (artboard F): the handlebar screen. Lights few pixels, no precision targets.
/// The LOG band logs a draft; hold the bottom band 2 s to stop. An unfinished ride
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
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @State private var music = MusicController()
    @State private var page: Int? = 0   // 0 telemetry, 1 music
    @State private var dark = false     // screen-off mode (decision 88)
    @State private var waking = false
    @State private var brightness: CGFloat?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Phone on its side: the handlebar layout (decision 85).
    private var landscape: Bool { verticalSizeClass == .compact }

    /// Above this the gauge is full. A scale, not a limit.
    static let gaugeMaxKph = 120.0

    var body: some View {
        VStack(spacing: 0) {
            if let orphan = recorder.orphan { RecoveryView(ride: orphan) } else if dark { blackout } else { riding }
        }
        .background(Color.ground.ignoresSafeArea())
        .statusBarHidden(dark)
        .persistentSystemOverlays(dark ? .hidden : .automatic)
        // Never leave the phone dimmed: wake when the app goes back, the ride changes state, or the screen closes.
        .onChange(of: scenePhase) { _, phase in if phase != .active { setDark(false) } }
        .onChange(of: recorder.phase) { setDark(false) }
        .sensoryFeedback(.impact(weight: .light), trigger: dark)
        .background { VolumeHost(music: music).frame(width: 1, height: 1) }
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true    // readable on the bars
            OrientationLock.set(.allButUpsideDown)
            music.start()
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
            setDark(false)
            OrientationLock.set(.portrait)
            music.stop()
        }
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
            if landscape {
                landscapeBody(now: context.date)
            } else {
                VStack(spacing: 0) {
                    topBar(now: context.date)
                    centre(now: context.date)
                    logButton
                    HStack(spacing: 0) {
                        pauseBand
                        stopBand
                    }
                }
            }
        }
    }

    // MARK: Screen off

    /// iOS has no call to lock the phone. Black pixels at zero brightness is the nearest thing:
    /// the OLED is off, touches do nothing, the ride keeps recording. Hold 1 s to wake.
    private var blackout: some View {
        Color.ground.ignoresSafeArea()
            .overlay {
                if waking {
                    Text("KEEP HOLDING").font(.oswald(18, .medium)).tracking(4).foregroundStyle(Color.inkMuted)
                }
            }
            .contentShape(Rectangle())
            .onLongPressGesture(minimumDuration: 1, maximumDistance: 60) { setDark(false) } onPressingChanged: { waking = $0 }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Screen off. The ride is recording.")
            .accessibilityHint("Hold for one second to wake.")
            .accessibilityAction { setDark(false) }
    }

    private func setDark(_ on: Bool) {
        guard on != dark else { return }
        if on {
            brightness = UIScreen.main.brightness
            UIScreen.main.brightness = 0
        } else if let was = brightness {
            UIScreen.main.brightness = was
            brightness = nil
        }
        waking = false
        dark = on
    }

    // MARK: Landscape

    /// Gauge left; km, music and volume right; LOG, PAUSE and STOP along the bottom (artboard F, landscape).
    private func landscapeBody(now: Date) -> some View {
        let speed = currentKph(now)
        let paused = recorder.phase == .paused
        return VStack(spacing: 0) {
            topBar(now: now)
            HStack(spacing: 24) {
                ZStack {
                    Gauge(fraction: (speed ?? 0) / Self.gaugeMaxKph, size: 190)
                    VStack(spacing: 4) {
                        Text(speed.map { String(Int($0.rounded())) } ?? "--")
                            .font(.oswald(88, .bold)).monospacedDigit().tracking(-2)
                            .foregroundStyle(speed == nil ? Color.inkFaint : Color.ink)
                            .lineLimit(1).minimumScaleFactor(0.5)
                            .rolling((speed ?? 0).rounded())
                        Text(speed == nil ? statusLabel(nil) : "KM/H").font(.oswald(15, .medium)).tracking(3.6)
                            .foregroundStyle(Color.inkMuted)
                    }
                }
                .frame(width: 300).frame(maxHeight: .infinity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(speed.map { "Speed \(Int($0)) kilometres per hour" } ?? statusLabel(nil))
                infoPane
            }
            .padding(.horizontal, 16)
            HStack(spacing: 10) {
                CaptureButton(title: failed ? "COULDN'T SAVE · TAP AGAIN" : flash ? "DRAFT LOGGED · \(logged)" : "LOG", action: log)
                    .fireRing(logged)
                Button { paused ? recorder.resumeFromPause() : recorder.pause() } label: {
                    Text(paused ? "RESUME" : "PAUSE").font(.oswald(22, .semibold)).tracking(4)
                        .foregroundStyle(paused ? Color.accent : Color.inkDim)
                        .frame(maxWidth: .infinity, minHeight: 106)
                        .overlay { Rectangle().stroke(paused ? Color.accent : Color.surfaceRule, lineWidth: 1) }
                        .contentShape(Rectangle())
                }
                .buttonStyle(PressStyle(haptic: false))
                stopBand
            }
            .padding(.horizontal, 16)
        }
    }

    /// One thing at a time: swipe up or down between telemetry and music (decision 87).
    private var infoPane: some View {
        GeometryReader { g in
            ScrollView(.vertical) {
                VStack(spacing: 0) {
                    paneTelemetry.frame(height: g.size.height).id(0)
                    paneMusic.frame(height: g.size.height).id(1)
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $page)
            .scrollIndicators(.hidden)
            .overlay(alignment: .trailing) {
                VStack(spacing: 10) {
                    ForEach(0..<2, id: \.self) { i in
                        Circle().fill((page ?? 0) == i ? Color.accent : Color.inkFaint).frame(width: 8, height: 8)
                    }
                }
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
        }
        .frame(maxHeight: .infinity)
    }

    private func paneTitle(_ text: String) -> some View {
        Text(text).font(.oswald(13, .medium)).tracking(2.6).foregroundStyle(Color.inkMuted)
    }

    private var paneTelemetry: some View {
        VStack(alignment: .leading, spacing: 0) {
            paneTitle("TELEMETRY")
            Spacer(minLength: 0)
            HStack(spacing: 28) {
                stat(String(format: "%.1f", recorder.stats.distanceM / 1000), "KM")
                stat("+\(Int(recorder.stats.climbM))", "M CLIMB")
                stat(String(Int((recorder.stats.maxSpeedMps * 3.6).rounded())), "TOP KM/H")
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(.trailing, 20)
    }

    private var paneMusic: some View {
        VStack(alignment: .leading, spacing: 6) {
            paneTitle("MUSIC")
            Spacer(minLength: 0)
            MusicStrip(music: music)
            Spacer(minLength: 0)
            VolumeRow(music: music)
        }
        .padding(.trailing, 20)
    }

    private func topBar(now: Date) -> some View {
        let paused = recorder.phase == .paused
        // Two buttons only, one per corner: a gloved thumb can't hit the wrong one (decision 89).
        return HStack(spacing: 8) {
            Button { setDark(true) } label: {
                Text("LOCK").font(.oswald(15, .semibold)).tracking(1.5).foregroundStyle(Color.inkDim)
                    .frame(minWidth: 96, minHeight: minTouch)
                    .overlay { Rectangle().stroke(Color.surfaceRule, lineWidth: 1) }
                    .contentShape(Rectangle())
            }
            .buttonStyle(PressStyle(haptic: false))
            .accessibilityLabel("Screen off")
            .accessibilityHint("Turns the screen black. The ride keeps recording. Hold one second to wake.")
            Spacer()
            // Breathes once every 4 s while recording: alive, but idle between beats for the battery (decision 101).
            let beat = !paused && !reduceMotion && Int(now.timeIntervalSinceReferenceDate) % 4 == 0
            Circle().fill(flash ? Color.ink : Color.accent).frame(width: 10, height: 10)
                .opacity(paused ? 0.4 : 1)
                .scaleEffect(beat ? 1.35 : 1)
                .animation(.easeInOut(duration: 0.5), value: beat)
            Text(paused ? "PAUSED" : "REC").font(.oswald(13, .medium)).tracking(2.6).foregroundStyle(Color.inkMuted)
            Text(clock(recorder.elapsed(at: now))).font(.oswald(17, .medium)).monospacedDigit().foregroundStyle(Color.inkMuted)
            Spacer()
            // CLOSE far right like every sheet; it only leaves the screen, the ride keeps recording.
            Button { dismiss() } label: {
                Text("CLOSE").font(.oswald(15, .semibold)).tracking(1.5).foregroundStyle(Color.inkDim)
                    .frame(minWidth: 96, minHeight: minTouch)
                    .overlay { Rectangle().stroke(Color.surfaceRule, lineWidth: 1) }
                    .contentShape(Rectangle())
            }
            .buttonStyle(PressStyle())
            .accessibilityLabel("Close. The ride keeps recording.")
        }
        .padding(.horizontal, 16)
    }

    /// Portrait PAUSE: a full-height band left of HOLD TO STOP, off the top bar.
    private var pauseBand: some View {
        let paused = recorder.phase == .paused
        return Button { paused ? recorder.resumeFromPause() : recorder.pause() } label: {
            Text(paused ? "RESUME" : "PAUSE").font(.oswald(18, .medium)).tracking(4)
                .foregroundStyle(paused ? Color.accent : Color.inkDim)
                .frame(width: 140, height: 116)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle(haptic: false))
        .overlay(alignment: .top) { Rectangle().fill(Color.surfaceRule).frame(height: 1) }
        .overlay(alignment: .trailing) { Rectangle().fill(Color.surfaceRule).frame(width: 1) }
    }

    private func centre(now: Date) -> some View {
        let speed = currentKph(now)
        return VStack(spacing: 8) {
            ZStack {
                Gauge(fraction: (speed ?? 0) / Self.gaugeMaxKph, size: 216)   // smaller: the pane below needs the room
                VStack(spacing: 6) {
                    Text(speed.map { String(Int($0.rounded())) } ?? "--")
                        .font(.oswald(120, .bold)).monospacedDigit().tracking(-2)
                        .foregroundStyle(speed == nil ? Color.inkFaint : Color.ink)
                        .lineLimit(1).minimumScaleFactor(0.5)
                        .rolling((speed ?? 0).rounded())
                    Text(statusLabel(speed)).font(.oswald(15, .medium)).tracking(3.6).foregroundStyle(Color.inkMuted)
                }
                .padding(.top, 12)
            }
            .frame(width: 300, height: 240)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(speed.map { "Speed \(Int($0)) kilometres per hour" } ?? statusLabel(nil))
            // Same swipe pane as landscape: the mount covers the hardware buttons (decision 90).
            infoPane.padding(.leading, 20).padding(.trailing, 12).padding(.bottom, 8)
        }
        .padding(.top, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// One deliberate target: a stray tap on the gauge used to log a draft.
    private var logButton: some View {
        Button(action: log) {
            Text(failed ? "COULDN'T SAVE · TAP AGAIN" : flash ? "DRAFT LOGGED · \(logged)" : "LOG")
                .font(.oswald(failed || flash ? 18 : 28, .semibold)).tracking(failed || flash ? 2.7 : 6)
                .foregroundStyle(failed ? Color.alarmInk : Color.accent)
                .frame(maxWidth: .infinity, minHeight: 116)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
        .fireRing(logged)
        .overlay(alignment: .top) { Rectangle().fill(Color.surfaceRule).frame(height: 1) }
        .accessibilityLabel("Log a draft")
        .accessibilityHint("Saves the time and place. Complete it later on Today.")
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
        .frame(height: landscape ? 106 : 116)
        .overlay {
            if landscape { Rectangle().stroke(Color.surfaceRule, lineWidth: 1) }
        }
        .overlay(alignment: .top) { if !landscape { Rectangle().fill(Color.surfaceRule).frame(height: 1) } }
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
        return String(format: "%d:%02d:%02d", s / 3600, s / 60 % 60, s % 60)
    }
}

/// 4pt stroked arc over 270°, unlit track, nine ticks outside the band (three major). Never filled (DESIGN.md).
/// The arc eases between readings instead of jumping, and self-tests on open (decision 101).
private struct Gauge: View {
    let fraction: Double
    var size: CGFloat = 240
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Set only during the self-test: full sweep to the end of the dial and back, like a cluster at ignition.
    @State private var test: Double?
    /// Once per Ride mode open, not again when the phone turns and the gauge is rebuilt.
    private static var lastTest = Date.distantPast

    var body: some View {
        let shown = min(1, max(0, test ?? fraction))
        ZStack {
            arc.trim(from: 0, to: 0.75).stroke(Color.surfaceLine, lineWidth: 4)
            arc.trim(from: 0, to: 0.75 * shown).stroke(Color.accent, lineWidth: 4)
                .animation(reduceMotion ? nil : (test == nil ? Motion.sweep : Motion.ignition), value: shown)
            // Placed by angle (rotate in place, then move out), so every tick sits exactly on the arc's radius, 4pt clear of the band.
            ForEach(0...8, id: \.self) { i in
                let major = i % 4 == 0
                let length: CGFloat = major ? 10 : 6
                let angle = Angle.degrees(135 + Double(i) / 8 * 270)
                let r = size / 2 + 6 + length / 2
                Rectangle().fill(major ? Color.inkMuted : Color.inkFaint).frame(width: 2, height: length)
                    .rotationEffect(angle + .degrees(90))
                    .offset(x: r * cos(angle.radians), y: r * sin(angle.radians))
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
        .task {
            guard !reduceMotion, Date.now.timeIntervalSince(Self.lastTest) > 30 else { return }
            Self.lastTest = .now
            test = 0
            try? await Task.sleep(for: .milliseconds(150))
            test = 1                                            // slow, to the very end of the dial
            try? await Task.sleep(for: .milliseconds(2000))    // 1.6s sweep + a beat at full
            test = 0
            try? await Task.sleep(for: .milliseconds(1500))
            test = nil
        }
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
