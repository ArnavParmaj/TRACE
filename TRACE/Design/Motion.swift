import SwiftUI

/// Motion tokens and the few moving parts (decision 101). Like `Tokens.swift` for colour:
/// views use these, never an ad-hoc curve. Only outlines, arcs and hairlines move;
/// no filled slab ever lights up (DESIGN.md rule 2).
enum Motion {
    /// Tabs, toggles, stamps: quick, a little overshoot.
    static let snap = Animation.spring(response: 0.42, dampingFraction: 0.72)
    /// A stamp landing: more overshoot than `snap`, so it reads as a thump.
    static let stamp = Animation.spring(response: 0.36, dampingFraction: 0.58)
    /// Screen-open stagger: each block rises 10pt and fades in.
    static let reveal = Animation.easeOut(duration: 0.5)
    static let revealStep = 0.06
    static let revealMax = 8
    /// Section rules extending, progress bars filling.
    static let extend = Animation.easeOut(duration: 0.6)
    /// Ride mode gauge: ease in and out, so the arc never jerks between 1 s readings.
    /// Ride-mode gauge self-test: slow and even, so the needle visibly reaches the end of the dial.
    static let ignition = Animation.timingCurve(0.35, 0, 0.25, 1, duration: 1.6)
    static let sweep = Animation.timingCurve(0.45, 0, 0.2, 1, duration: 1.1)
    /// Under Reduce Motion every move becomes this. Haptics stay.
    static let reduced = Animation.easeOut(duration: 0.2)
}

// MARK: Ignition

/// The screen-open sequence plays the first time each screen opens per launch, not on every return.
@MainActor enum Ignition {
    private static var played: Set<String> = []

    /// True the first time `screen` asks this launch, false after.
    static func claim(_ screen: String) -> Bool { played.insert(screen).inserted }
}

extension EnvironmentValues {
    /// True while the current screen is playing its ignition. Set once, at the screen's root.
    @Entry var ignite = false
}

/// Staggered rise-in for one block of a screen. With no ignition it is simply shown:
/// the resting state is always fully visible.
private struct Reveal: ViewModifier {
    let index: Int
    @Environment(\.ignite) private var ignite
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    func body(content: Content) -> some View {
        let hidden = ignite && !shown
        content
            .opacity(hidden ? 0 : 1)
            .offset(y: hidden && !reduceMotion ? 10 : 0)
            .onAppear {
                guard ignite, !shown else { return }
                let delay = 0.12 + Double(min(index, Motion.revealMax)) * Motion.revealStep
                withAnimation((reduceMotion ? Motion.reduced : Motion.reveal).delay(delay)) { shown = true }
            }
    }
}

extension View {
    /// One block of a screen's ignition, `index` in reading order.
    func reveal(_ index: Int) -> some View { modifier(Reveal(index: index)) }

    /// Oswald figures roll digit by digit when they change, instead of swapping.
    func rolling(_ value: Double) -> some View {
        contentTransition(.numericText(value: value)).animation(Motion.snap, value: value)
    }
}

// MARK: Confirmations

/// An outline that pushes out from a control and fades: the visual half of a success haptic.
/// Outline only, never a fill. Invisible at rest.
private struct FireRing: ViewModifier {
    let trigger: Int
    var color = Color.accent
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    struct Frame { var spread: CGFloat = 0; var opacity: Double = 0 }

    func body(content: Content) -> some View {
        content.overlay {
            if !reduceMotion {
                Rectangle().stroke(color, lineWidth: 2)
                    .keyframeAnimator(initialValue: Frame(), trigger: trigger) { ring, f in
                        ring.padding(-f.spread).opacity(f.opacity)
                    } keyframes: { _ in
                        KeyframeTrack(\.opacity) {
                            MoveKeyframe(0.9)
                            LinearKeyframe(0, duration: 0.7)
                        }
                        KeyframeTrack(\.spread) {
                            MoveKeyframe(0)
                            CubicKeyframe(18, duration: 0.7)
                        }
                    }
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
    }
}

extension View {
    /// Fires an amber ring each time `trigger` changes.
    func fireRing(_ trigger: Int, color: Color = .accent) -> some View {
        modifier(FireRing(trigger: trigger, color: color))
    }
}

/// LOGGED, DONE, SAVED: an outlined amber slug that lands with a thump, tilted like a rubber stamp.
/// Outlined, never filled. Pair it with the success haptic on the same frame (decision 52).
struct Stamp: View {
    let text: String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var landed = false

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text).font(.oswald(15, .bold)).tracking(3).foregroundStyle(Color.accent)
            .padding(.horizontal, 10).padding(.vertical, 3)
            .background(Color.ground)
            .overlay { Rectangle().stroke(Color.accent, lineWidth: 2) }
            .rotationEffect(.degrees(-7))
            .scaleEffect(landed || reduceMotion ? 1 : 2.2)
            .opacity(landed ? 1 : 0)
            .onAppear { withAnimation(reduceMotion ? Motion.reduced : Motion.stamp) { landed = true } }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

/// Fusion made visible: an expense flies in and snaps onto its ride, `index` in list order.
/// Plays whenever the row first appears, so attaching one later lands the same way.
private struct FlyIn: ViewModifier {
    let index: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var landed = false

    func body(content: Content) -> some View {
        let away = !landed && !reduceMotion
        content
            .offset(x: away ? 60 : 0, y: away ? -24 : 0)
            .rotationEffect(.degrees(away ? 6 : 0))
            .opacity(landed ? 1 : 0)
            .onAppear {
                guard !landed else { return }
                let delay = 0.5 + Double(min(index, 6)) * 0.14
                withAnimation((reduceMotion ? Motion.reduced : Motion.stamp).delay(delay)) { landed = true }
            }
    }
}

extension View {
    func flyIn(_ index: Int) -> some View { modifier(FlyIn(index: index)) }
}

// MARK: Empty states

/// An empty section: a short amber line in Oswald caps, then what to do (SCREENS rule 7).
/// Dashed hairline, nothing lit.
struct EmptyNote: View {
    let kicker: String
    let line: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(kicker).font(.oswald(16, .semibold)).tracking(1.6).foregroundStyle(Color.accent)
            Text(line).font(.condensed(16)).foregroundStyle(Color.inkDim).fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay { Rectangle().stroke(Color.surfaceRule, style: StrokeStyle(lineWidth: 1, dash: [4, 4])) }
        .accessibilityElement(children: .combine)
    }
}
