import SwiftUI

/// Design tokens from design/DESIGN.md. Hand-maintained (decision 41);
/// TokenTests fails if this file and DESIGN.md disagree. Views use `Color.ink` etc.,
/// never a hex.
enum Token: String, CaseIterable {
    case ground = "--ground"
    case surfaceLine = "--surface-line"
    case surfaceRule = "--surface-rule"
    case diagonal = "--diagonal"
    case ink = "--ink"
    case inkDim = "--ink-dim"
    case inkMuted = "--ink-muted"
    case inkFaint = "--ink-faint"
    case accent = "--accent"
    case alarm = "--alarm"
    case alarmInk = "--alarm-ink"
    case warn = "--warn"

    var hex: UInt32 {
        switch self {
        case .ground: 0x000000
        case .surfaceLine: 0x1E1C1A
        case .surfaceRule: 0x2A2724
        case .diagonal: 0x1A1714
        case .ink: 0xF2EFE9
        case .inkDim: 0xC9C5BF
        case .inkMuted: 0x8A8681
        case .inkFaint: 0x6E6B67
        case .accent: 0xFF8A3D
        case .alarm: 0xE0241B
        case .alarmInk: 0xFF6A5F
        case .warn: 0xE8B84B
        }
    }

    var color: Color {
        Color(.sRGB,
              red: Double((hex >> 16) & 0xFF) / 255,
              green: Double((hex >> 8) & 0xFF) / 255,
              blue: Double(hex & 0xFF) / 255)
    }
}

extension Color {
    static let ground = Token.ground.color
    static let surfaceLine = Token.surfaceLine.color
    static let surfaceRule = Token.surfaceRule.color
    static let diagonal = Token.diagonal.color
    static let ink = Token.ink.color
    static let inkDim = Token.inkDim.color
    static let inkMuted = Token.inkMuted.color
    static let inkFaint = Token.inkFaint.color
    static let accent = Token.accent.color
    /// Overdue / expired / urgent only. Borders and fills; text uses `alarmInk`.
    static let alarm = Token.alarm.color
    static let alarmInk = Token.alarmInk.color
    static let warn = Token.warn.color
}

extension Font {
    /// Numerals, labels, display. Scales with Dynamic Type relative to `style`.
    static func oswald(_ size: CGFloat, _ weight: Font.Weight = .semibold,
                       relativeTo style: Font.TextStyle = .body) -> Font {
        .custom("Oswald", size: size, relativeTo: style).weight(weight)
    }

    /// Body, row labels, helper text.
    static func condensed(_ size: CGFloat, _ weight: Font.Weight = .regular,
                          relativeTo style: Font.TextStyle = .body) -> Font {
        .custom("Roboto Condensed", size: size, relativeTo: style).weight(weight)
    }
}

/// Minimum touch target: gloves (invariant 10).
let minTouch: CGFloat = 60

/// The one button style: feedback on touch-down, no bounce (SCREENS §6).
/// A light tap haptic on touch-down confirms the press through gloves (decision 52).
/// Buttons whose outcome has its own haptic pass `haptic: false`, so nothing buzzes twice.
struct PressStyle: ButtonStyle {
    var haptic = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .opacity(configuration.isPressed && reduceMotion ? 0.7 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 1), value: configuration.isPressed)
            .sensoryFeedback(.impact(weight: .light), trigger: configuration.isPressed) { _, pressed in
                haptic && pressed
            }
    }
}
