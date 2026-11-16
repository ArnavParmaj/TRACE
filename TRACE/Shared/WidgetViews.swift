import AppIntents
import SwiftUI

/// The home-screen widget's drawing (decision 91), shared with the app so the debug gallery
/// shows exactly what the widget shows. Medium: panel left, START RIDE and LOG right.
/// Small: the panel alone. Only the panel changes with state; the buttons never move.
struct WidgetPanel: View {
    let snapshot: WidgetSnapshot
    let now: Date
    var small = false
    /// Medium only: the head and the bottom line are two links, each to what it shows (decision 93).
    /// A small widget takes one link for the whole square, set by the widget itself.
    var links = false

    var body: some View {
        let state = snapshot.state(at: now)
        // The bottom line names the next thing due unless the head already does.
        let next: DueLine? = if case .due = state { nil } else { snapshot.dueLines(at: now).first }
        VStack(alignment: .leading, spacing: 0) {
            linked(WidgetLink.panel(state)) {
                VStack(alignment: .leading, spacing: 0) {
                    head(state)
                    Spacer(minLength: 4)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .contentShape(Rectangle())   // the gaps are part of the link too, or a tap there opens the app nowhere
                .accessibilityElement(children: .combine)
            }
            Rectangle().fill(Color.surfaceRule).frame(height: 1)
            linked(next?.target.flatMap { URL(string: "trace://\($0)") } ?? WidgetLink.url(.bike)) {
                footer(next?.label).padding(.top, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .accessibilityElement(children: .combine)
            }
        }
    }

    @ViewBuilder private func linked<V: View>(_ url: URL, @ViewBuilder _ content: () -> V) -> some View {
        if links { Link(destination: url, label: content) } else { content() }
    }

    // MARK: Head

    @ViewBuilder private func head(_ state: WidgetState) -> some View {
        switch state {
        case .riding(let live):
            HStack(spacing: 8) {
                Circle().fill(Color.accent).frame(width: 9, height: 9).opacity(live.pausedS == nil ? 1 : 0.4)
                label(live.pausedS == nil ? "REC" : "PAUSED")
            }
            Group {
                if let s = live.pausedS {
                    Text(String(format: "%d:%02d:%02d", s / 3600, s / 60 % 60, s % 60))
                } else {
                    // A system timer: it ticks on the home screen with no refresh.
                    Text(timerInterval: live.clockStart...Date.distantFuture, countsDown: false)
                }
            }
            .font(.oswald(small ? 34 : 44, .bold)).monospacedDigit().foregroundStyle(Color.ink)
            .lineLimit(1).minimumScaleFactor(0.6)
            label("STARTED \(live.startedAt.formatted(date: .omitted, time: .shortened).uppercased())")
        case .due(let line):
            let tone: Color = line.urgency == .overdue ? .alarmInk : line.urgency == .soon ? .accent : .ink
            label(line.urgency == .overdue ? "OVERDUE" : line.urgency == .soon ? "DUE SOON" : "NEXT DUE",
                  color: line.urgency == .overdue ? .alarmInk : line.urgency == .soon ? .accent : .inkMuted)
            title(line.label)
            if line.amount == 0 {
                Text("TODAY").font(.oswald(34, .bold)).foregroundStyle(tone)
            } else {
                number(line.amount.formatted(), "\(line.unit) \(line.urgency == .overdue ? "OVER" : "LEFT")", color: tone)
            }
        case .drafts(let n):
            label("TO COMPLETE")
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(n)").font(.oswald(52, .bold)).monospacedDigit().foregroundStyle(Color.accent)
                Text(n == 1 ? "LOG" : "LOGS").font(.oswald(20, .semibold)).foregroundStyle(Color.ink)
            }
            if !small { Text("Tap to fill in the details").font(.condensed(14, .medium)).foregroundStyle(Color.inkDim) }
        case .recap(let ride):
            label("RIDE DONE")
            number(km(ride.km), "KM", size: 52)
            HStack(spacing: 14) {
                pair("\(ride.minutes)", after: "MIN")
                pair("\(ride.topKph)", before: "TOP")
            }
        case .best(let best):
            HStack(spacing: 8) {
                Text("PB").font(.oswald(11, .semibold)).tracking(2.2).foregroundStyle(Color.accent)
                    .padding(.horizontal, 5).padding(.vertical, 1)
                    .overlay { Rectangle().stroke(Color.accent, lineWidth: 1) }
                label("NEW BEST")
            }
            title(best.title)
            number(best.value, best.unit)
        case .parked(let days, let last):
            label("PARKED")
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(days)").font(.oswald(52, .bold)).monospacedDigit().foregroundStyle(Color.ink)
                Text("DAYS").font(.oswald(20, .semibold)).foregroundStyle(Color.ink)
            }
            label("LAST RIDE \(last.endedAt.formatted(.dateTime.day().month(.abbreviated)).uppercased()) · \(km(last.km)) KM")
        case .empty(let text):
            label("TRACE")
            title(text)
        }
    }

    // MARK: Footer

    @ViewBuilder private func footer(_ next: String?) -> some View {
        if let next {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                if !small { label("NEXT DUE") }
                Text(next).font(.oswald(15, .semibold)).foregroundStyle(Color.ink).lineLimit(1)
            }
        } else {
            HStack(alignment: .firstTextBaseline, spacing: 18) {
                if !small { pair("\(snapshot.weekKm(at: now))", before: "WEEK") }
                pair(snapshot.odometerKm.formatted(), before: "ODO")
            }
        }
    }

    // MARK: Pieces

    private func label(_ text: String, color: Color = .inkMuted) -> some View {
        Text(text).font(.oswald(11, .medium)).tracking(2.2).foregroundStyle(color).lineLimit(1).minimumScaleFactor(0.7)
    }

    private func title(_ text: String) -> some View {
        Text(text).font(.oswald(20, .semibold)).tracking(0.5).foregroundStyle(Color.ink)
            .lineLimit(1).minimumScaleFactor(0.6).padding(.top, 4)
    }

    private func number(_ value: String, _ unit: String, color: Color = .ink, size: CGFloat = 40) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(value).font(.oswald(size, .bold)).monospacedDigit().foregroundStyle(color).lineLimit(1).minimumScaleFactor(0.6)
            label(unit)
        }
    }

    private func pair(_ value: String, before: String? = nil, after: String? = nil) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            if let before { label(before) }
            Text(value).font(.oswald(15, .semibold)).monospacedDigit().foregroundStyle(Color.ink)
            if let after { label(after) }
        }
    }

    private func km(_ value: Double) -> String { value < 10 ? String(format: "%.1f", value) : String(Int(value.rounded())) }
}

/// START RIDE (OPEN RIDE while one is on) and LOG. Each 65 pt tall: gloves (invariant 10).
struct WidgetActions: View {
    let riding: Bool
    /// True for a few seconds after a log: the button itself says it worked.
    var logged = false

    var body: some View {
        VStack(spacing: 8) {
            // GPS can only start with the app in front, so this opens TRACE already recording.
            Link(destination: WidgetLink.url(riding ? .ride : .start)) {
                HStack(spacing: 8) {
                    if !riding { Image(systemName: "play.fill").font(.system(size: 12)).foregroundStyle(Color.accent) }
                    Text(riding ? "OPEN RIDE" : "START RIDE").font(.oswald(17, .semibold)).tracking(2.5).foregroundStyle(Color.ink)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay { Rectangle().stroke(Color.surfaceRule, lineWidth: 1) }
                .contentShape(Rectangle())
            }
            // The capture button (DESIGN.md): black, 2 pt amber border, 10 pt spine. Runs in place.
            Button(intent: LogEntryIntent(confirm: true)) {
                Text(logged ? "LOGGED" : "LOG").font(.oswald(logged ? 17 : 22, .semibold)).tracking(logged ? 2.5 : 5)
                    .foregroundStyle(logged ? Color.ink : Color.accent)
                    .padding(.leading, 26)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    .overlay(alignment: .leading) { Rectangle().fill(Color.accent).frame(width: 10) }
                    .overlay { Rectangle().stroke(Color.accent, lineWidth: 2) }
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Log a draft")
        }
        .frame(width: 132)
    }
}

/// The small start widget: the whole square is the button.
struct WidgetStartTile: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        let riding = snapshot.live != nil
        VStack(alignment: .leading, spacing: 0) {
            Image(systemName: riding ? "arrow.up.right" : "play.fill").font(.system(size: 16, weight: .bold)).foregroundStyle(Color.accent)
            Text(riding ? "OPEN\nRIDE" : "START\nRIDE").font(.oswald(26, .bold)).tracking(1.5)
                .foregroundStyle(Color.accent).fixedSize(horizontal: false, vertical: true).padding(.top, 4)
            Spacer(minLength: 0)
            Text("ODO \(snapshot.odometerKm.formatted()) KM").font(.oswald(11, .medium)).tracking(2.2).foregroundStyle(Color.inkMuted)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .overlay { RoundedRectangle(cornerRadius: 12).stroke(Color.accent, lineWidth: 2) }
        .padding(12)   // the widget's own margins are off, so the outline sits 12 pt in
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(riding ? "Open ride" : "Start ride")
    }
}

/// Where a tap on the widget lands in the app. `task`, `doc` and `trip` carry an id: trace://task/<id>.
enum WidgetLink: String {
    case start, ride, today, bike, drafts, task, doc, trip

    static func url(_ link: WidgetLink) -> URL { URL(string: "trace://\(link.rawValue)")! }

    /// The screen that matches what the panel shows: the task or document itself, the draft to
    /// complete, the ride just done or holding the best, Ride mode while riding.
    static func panel(_ state: WidgetState) -> URL {
        func trip(_ id: UUID?) -> URL { id.flatMap { URL(string: "trace://trip/\($0)") } ?? url(.today) }
        return switch state {
        case .riding: url(.ride)
        case .due(let line): line.target.flatMap { URL(string: "trace://\($0)") } ?? url(.bike)
        case .drafts: url(.drafts)
        case .recap(let ride): trip(ride.id)
        case .best(let best): trip(best.rideID)
        case .parked: url(.today)
        case .empty: url(.bike)
        }
    }

    /// The link's kind and the record it names, if any.
    static func parse(_ url: URL) -> (link: WidgetLink, id: UUID?)? {
        guard let link = url.host.flatMap(WidgetLink.init) else { return nil }
        return (link, UUID(uuidString: url.lastPathComponent))
    }
}

#if DEBUG && !WIDGET_EXTENSION
/// `-widgetGallery`: every widget state at its real size, for simulator screenshots only.
struct WidgetGallery: View {
    static let now = Date(timeIntervalSince1970: 1_794_700_000)

    static var samples: [(String, WidgetSnapshot)] {
        let day = 86_400.0
        var base = WidgetSnapshot(hasBike: true, odometerKm: 1782)
        base.tasks = [.init(label: "Chain lube", lastDoneOdoKm: 1402, intervalKm: 500)]
        base.docs = [.init(label: "Insurance", expiresOn: now.addingTimeInterval(200 * day))]
        base.rides = [.init(endedAt: now.addingTimeInterval(-2 * day), km: 31.4, minutes: 88, topKph: 84)]
        var riding = base; riding.live = .init(startedAt: now.addingTimeInterval(-2530), clockStart: Date.now.addingTimeInterval(-2530))
        var overdue = base; overdue.odometerKm = 1942
        var drafts = base; drafts.drafts = 2
        var recap = base; recap.rides[0].endedAt = now.addingTimeInterval(-1800)
        var soon = base; soon.docs[0].expiresOn = now.addingTimeInterval(12 * day)
        var best = base; best.best = .init(title: "LONGEST RIDE", value: "62", unit: "KM", at: now.addingTimeInterval(-5 * 3600))
        var parked = base; parked.rides[0].endedAt = now.addingTimeInterval(-9 * day)
        return [("1 RIDING", riding), ("2 OVERDUE", overdue), ("3 LOGS", drafts), ("4 RECAP", recap),
                ("5 DUE SOON", soon), ("6 NEW BEST", best), ("7 PARKED", parked), ("8 DEFAULT", base),
                ("NO BIKE", WidgetSnapshot())]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                ForEach(Self.samples, id: \.0) { name, snapshot in
                    Text(name).font(.oswald(11, .medium)).tracking(2.2).foregroundStyle(Color.inkMuted)
                    HStack(spacing: 16) {
                        WidgetPanel(snapshot: snapshot, now: Self.now, links: true)
                        WidgetActions(riding: snapshot.live != nil, logged: snapshot.justLogged(at: Self.now))
                    }
                    .padding(16).frame(width: 364, height: 170).overlay { RoundedRectangle(cornerRadius: 22).stroke(Color.surfaceRule) }
                    HStack(spacing: 12) {
                        WidgetPanel(snapshot: snapshot, now: Self.now, small: true)
                            .padding(16).frame(width: 170, height: 170).overlay { RoundedRectangle(cornerRadius: 22).stroke(Color.surfaceRule) }
                        WidgetStartTile(snapshot: snapshot)
                            .frame(width: 170, height: 170).overlay { RoundedRectangle(cornerRadius: 22).stroke(Color.surfaceRule) }
                    }
                }
            }
            .padding(14)
        }
        .background(Color.ground.ignoresSafeArea())
    }
}
#endif
