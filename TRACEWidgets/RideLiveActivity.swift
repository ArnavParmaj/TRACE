import ActivityKit
import SwiftUI
import WidgetKit

@main
struct TRACEWidgets: WidgetBundle {
    var body: some Widget { RideLiveActivity() }
}

/// S18: elapsed, distance, REC dot and one LOG button (same intent as the Action Button).
/// Tapping anywhere else opens Ride mode.
struct RideLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RideActivityAttributes.self) { context in
            LockScreen(state: context.state)
                .activityBackgroundTint(.black)
                .activitySystemActionForegroundColor(.ink)
                .widgetURL(rideURL)
        } dynamicIsland: { context in
            let s = context.state
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 6) { Dot(paused: s.pausedAt != nil); Elapsed(state: s, size: 17) }
                        .padding(.leading, 6)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(km(s.km)).font(.oswald(17, .semibold)).monospacedDigit().foregroundStyle(Color.ink)
                        .padding(.trailing, 6)
                }
                DynamicIslandExpandedRegion(.bottom) { LogButton(drafts: s.drafts) }
            } compactLeading: {
                HStack(spacing: 4) { Dot(paused: s.pausedAt != nil); Elapsed(state: s, size: 14).frame(maxWidth: 52) }
            } compactTrailing: {
                Text(km(s.km)).font(.oswald(14, .semibold)).monospacedDigit().foregroundStyle(Color.ink)
            } minimal: {
                Dot(paused: s.pausedAt != nil)
            }
            .widgetURL(rideURL)
        }
    }
}

private let rideURL = URL(string: "trace://ride")

private func km(_ value: Double) -> String { String(format: "%.1f KM", value) }

private struct LockScreen: View {
    let state: RideActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Dot(paused: state.pausedAt != nil)
                Text(state.pausedAt == nil ? "TRACE · REC" : "TRACE · PAUSED")
                    .font(.oswald(13, .medium)).tracking(2.4).foregroundStyle(Color.inkMuted)
                Spacer()
                Elapsed(state: state, size: 22)
            }
            HStack(alignment: .bottom, spacing: 12) {
                Text(km(state.km)).font(.oswald(40, .bold)).monospacedDigit().foregroundStyle(Color.ink)
                Spacer()
                LogButton(drafts: state.drafts)
            }
        }
        .padding(16)
    }
}

private struct Dot: View {
    let paused: Bool
    var body: some View {
        Circle().fill(Color.accent).frame(width: 9, height: 9).opacity(paused ? 0.4 : 1).accessibilityHidden(true)
    }
}

/// A running system timer while riding, so it ticks without updates; frozen while paused.
private struct Elapsed: View {
    let state: RideActivityAttributes.ContentState
    let size: CGFloat

    var body: some View {
        Group {
            if let s = state.pausedAt {
                Text(String(format: "%d:%02d:%02d", s / 3600, s / 60 % 60, s % 60))
            } else {
                Text(timerInterval: state.clockStart...Date.distantFuture, countsDown: false)
            }
        }
        .font(.oswald(size, .semibold)).monospacedDigit().foregroundStyle(Color.ink)
    }
}

private struct LogButton: View {
    let drafts: Int
    var body: some View {
        Button(intent: LogEntryIntent()) {
            Text(drafts == 0 ? "LOG" : "LOG · \(drafts)").font(.oswald(18, .bold)).tracking(2.4).foregroundStyle(Color.ink)
                .frame(minWidth: 110, minHeight: 60)   // gloves (invariant 10)
                .overlay { RoundedRectangle(cornerRadius: 14).stroke(Color.accent, lineWidth: 2) }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(drafts == 0 ? "Log a draft" : "Log a draft. \(drafts) logged on this ride.")
    }
}
