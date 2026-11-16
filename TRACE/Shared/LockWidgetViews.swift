import SwiftUI
import WidgetKit

/// The three lock-screen shapes of the TRACE widget (decision 99): the same state ladder as the home
/// screen, in three short lines. The lock screen tints everything one colour, so state is told in words,
/// never by colour alone (SCREENS rule 6). No money here, ever (invariant 1): the lock screen is public.
struct LockLines: Equatable {
    var kicker: String
    var title: String
    var detail: String
    /// The circular shape: one big figure and its unit.
    var big: String
    var unit: String

    init(_ state: WidgetState) {
        func km(_ v: Double) -> String { v < 10 ? String(format: "%.1f", v) : String(Int(v.rounded())) }
        switch state {
        case .riding(let live): self.init("REC", live.pausedS == nil ? "RIDING" : "PAUSED", "", "REC", "")
        case .due(let line):
            let when = line.amount == 0 ? "TODAY" : "\(line.amount.formatted()) \(line.unit) \(line.urgency == .overdue ? "OVER" : "LEFT")"
            self.init(line.urgency == .overdue ? "OVERDUE" : line.urgency == .soon ? "DUE SOON" : "NEXT DUE", line.label, when,
                      line.amount == 0 ? "TODAY" : line.amount.formatted(), line.amount == 0 ? "" : line.unit)
        case .drafts(let n): self.init("TO COMPLETE", "\(n) \(n == 1 ? "LOG" : "LOGS")", "", "\(n)", n == 1 ? "LOG" : "LOGS")
        case .recap(let r): self.init("RIDE DONE", "\(km(r.km)) KM", "\(r.minutes) MIN · TOP \(r.topKph)", km(r.km), "KM")
        case .best(let b): self.init("NEW BEST", b.title, "\(b.value) \(b.unit)", "PB", "")
        case .parked(let days, _): self.init("PARKED", "\(days) \(days == 1 ? "DAY" : "DAYS")", "", "\(days)", days == 1 ? "DAY" : "DAYS")
        case .empty(let text): self.init("TRACE", text, "", "TRACE", "")
        }
    }

    private init(_ kicker: String, _ title: String, _ detail: String, _ big: String, _ unit: String) {
        self.kicker = kicker; self.title = title; self.detail = detail; self.big = big; self.unit = unit
    }
}

struct LockWidgetView: View {
    let snapshot: WidgetSnapshot
    let now: Date
    var shape: WidgetFamily?   // the debug gallery draws all three; the widget leaves it nil
    @Environment(\.widgetFamily) private var family

    var body: some View {
        let state = snapshot.state(at: now)
        let lines = LockLines(state)
        Group {
            switch shape ?? family {
            case .accessoryInline: inline(lines)
            case .accessoryCircular: circular(state, lines)
            default: rectangular(state, lines)
            }
        }
        .widgetURL(WidgetLink.panel(state))
    }

    private func inline(_ l: LockLines) -> some View {
        Text([l.title, l.detail].filter { !$0.isEmpty }.joined(separator: " · "))
    }

    private func rectangular(_ state: WidgetState, _ l: LockLines) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(l.kicker).font(.oswald(11, .medium)).tracking(1.8).widgetAccentable()
            if case .riding(let live) = state {
                clock(live).font(.oswald(24, .bold)).monospacedDigit()
            } else {
                Text(l.title).font(.oswald(16, .semibold)).lineLimit(1).minimumScaleFactor(0.7)
                if !l.detail.isEmpty { Text(l.detail).font(.condensed(13, .medium)).lineLimit(1) }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder private func circular(_ state: WidgetState, _ l: LockLines) -> some View {
        ZStack {
            AccessoryWidgetBackground()
            if case .riding = state {
                VStack(spacing: 0) {
                    Circle().frame(width: 6, height: 6).widgetAccentable()
                    Text("REC").font(.oswald(11, .semibold)).tracking(1.5)
                }
            } else {
                VStack(spacing: 0) {
                    Text(l.big).font(.oswald(20, .bold)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.5)
                    if !l.unit.isEmpty { Text(l.unit).font(.oswald(9, .medium)).tracking(1) }
                }
            }
        }
    }

    @ViewBuilder private func clock(_ live: WidgetSnapshot.Live) -> some View {
        if let s = live.pausedS {
            Text(String(format: "%d:%02d:%02d", s / 3600, s / 60 % 60, s % 60))
        } else {
            Text(timerInterval: live.clockStart...Date.distantFuture, countsDown: false)   // ticks with no refresh
        }
    }
}
