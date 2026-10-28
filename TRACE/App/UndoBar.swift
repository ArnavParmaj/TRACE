import SwiftUI

/// One pending UNDO at a time, for 5 s (SCREENS rule 8). Deletes are soft, so undo
/// just clears the tombstone. Shown by `.undoBar()` above the tab bar and inside sheets.
@MainActor
@Observable
final class UndoCenter {
    struct Offer: Identifiable {
        let id = UUID()
        let message: String
        let undo: () -> Void
    }

    static let seconds = 5.0
    private(set) var offer: Offer?

    func show(_ message: String, undo: @escaping () -> Void) {
        let new = Offer(message: message, undo: undo)
        offer = new
        AccessibilityNotification.Announcement("\(message). Undo available.").post()
        Task {
            try? await Task.sleep(for: .seconds(Self.seconds))
            if offer?.id == new.id { offer = nil }
        }
    }

    func undo() {
        offer?.undo()
        offer = nil
    }
}

extension View {
    /// Pins the undo bar to the bottom edge of this view while an offer is live.
    func undoBar() -> some View { modifier(UndoBarHost()) }
}

private struct UndoBarHost: ViewModifier {
    @Environment(UndoCenter.self) private var center

    func body(content: Content) -> some View {
        content.safeAreaInset(edge: .bottom, spacing: 0) {
            if let offer = center.offer {
                HStack(spacing: 12) {
                    Text(offer.message).font(.condensed(16)).foregroundStyle(Color.ink).lineLimit(2)
                    Spacer(minLength: 8)
                    Button { center.undo() } label: {
                        Text("UNDO").font(.oswald(16, .semibold)).tracking(1.8).foregroundStyle(Color.accent)
                            .frame(minWidth: 96, minHeight: minTouch).contentShape(Rectangle())
                    }
                    .buttonStyle(PressStyle())
                }
                .padding(.leading, 20).padding(.trailing, 8)
                .background(Color.ground)
                .overlay(alignment: .top) { Rectangle().fill(Color.surfaceRule).frame(height: 1) }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.18), value: center.offer?.id)
    }
}
