import Foundation

/// What the home-screen widget knows (decision 91). The app writes it to the App Group; the
/// widget works out what to show when it draws, so day counts move without the app (invariant 6).
/// No money in here, ever (invariant 1): a widget is on show to anyone who sees the phone.
struct WidgetSnapshot: Codable, Equatable, Sendable {
    struct Task: Codable, Equatable, Sendable {
        var id: UUID?   // what a tap opens
        var label: String
        var lastDoneOdoKm: Int?
        var lastDoneAt: Date?
        var intervalKm: Int?
        var intervalDays: Int?
    }
    struct Doc: Codable, Equatable, Sendable {
        var id: UUID?
        var label: String
        var expiresOn: Date
    }
    struct RideLite: Codable, Equatable, Sendable {
        var id: UUID?
        var endedAt: Date
        var km: Double
        var minutes: Int
        var topKph: Int
    }
    struct Best: Codable, Equatable, Sendable {
        var title: String
        var value: String
        var unit: String
        var at: Date
        var rideID: UUID?
    }
    struct Live: Codable, Equatable, Sendable {
        var startedAt: Date
        /// Ride start pushed later by time spent paused, so a running timer shows elapsed.
        var clockStart: Date
        /// Frozen elapsed seconds while paused; nil while riding.
        var pausedS: Int?
    }

    var hasBike = false
    var odometerKm = 0
    var soonShare = 0.15
    var tasks: [Task] = []
    var docs: [Doc] = []
    var drafts = 0
    /// Newest first: the last ride, plus every ride from the past 8 days for the week total.
    var rides: [RideLite] = []
    var best: Best?
    var live: Live?
    /// When the widget's LOG last ran, so its button can say LOGGED for a moment.
    var loggedAt: Date?
}

/// One service task or document, as the widget words it: "CHAIN LUBE · 120 KM LEFT".
struct DueLine: Equatable, Sendable {
    var label: String
    var urgency: Urgency
    var amount: Int
    var unit: String
    var progress = 0.0
    /// Where a tap goes, as a link path: "task/<id>" or "doc/<id>".
    var target: String?
}

/// The one thing the widget's panel shows. `WidgetSnapshot.state(at:)` picks it.
enum WidgetState: Equatable, Sendable {
    case riding(WidgetSnapshot.Live)
    /// Overdue, due soon or simply next: the line's urgency says which.
    case due(DueLine)
    case drafts(Int)
    case recap(WidgetSnapshot.RideLite)
    case best(WidgetSnapshot.Best)
    case parked(days: Int, last: WidgetSnapshot.RideLite)
    case empty(String)
}

extension WidgetSnapshot {
    static let recapForS: TimeInterval = 3 * 3600
    static let bestForS: TimeInterval = 24 * 3600
    static let parkedAfterDays = 7
    static let loggedForS: TimeInterval = 5

    func justLogged(at now: Date) -> Bool {
        loggedAt.map { (0..<Self.loggedForS).contains(now.timeIntervalSince($0)) } ?? false
    }

    /// Every active task and document, most urgent first. Urgency comes from `Due`, the same
    /// rule the Bike tab uses.
    func dueLines(at now: Date, calendar: Calendar = .current) -> [DueLine] {
        func unit(_ n: Int) -> String { n == 1 ? "DAY" : "DAYS" }
        var lines: [DueLine] = []
        for t in tasks {
            let status = Due.service(lastDoneOdoKm: t.lastDoneOdoKm, lastDoneAt: t.lastDoneAt, intervalKm: t.intervalKm,
                                     intervalDays: t.intervalDays, odometerKm: odometerKm, now: now,
                                     soonShare: soonShare, calendar: calendar)
            guard status.urgency != .unknown else { continue }
            var kmLeft: Int?, daysLeft: Int?
            if let i = t.intervalKm, i > 0, let last = t.lastDoneOdoKm { kmLeft = last + i - odometerKm }
            if let i = t.intervalDays, i > 0, let last = t.lastDoneAt,
               let day = calendar.date(byAdding: .day, value: i, to: last) {
                daysLeft = Due.days(from: now, to: day, calendar: calendar)
            }
            // Same order as Due.service: km wins when both are overdue or both are soon.
            let kmSoon = kmLeft.map { Double($0) <= Double(t.intervalKm ?? 0) * soonShare } ?? false
            let byKm: Bool = switch status.urgency {
            case .overdue: (kmLeft ?? 0) < 0
            case .soon: kmSoon
            default: kmLeft != nil
            }
            let left = byKm ? kmLeft ?? 0 : daysLeft ?? 0
            lines.append(DueLine(label: t.label.uppercased(), urgency: status.urgency, amount: abs(left),
                                 unit: byKm ? "KM" : unit(abs(left)), progress: status.progress ?? 0,
                                 target: t.id.map { "task/\($0)" }))
        }
        for d in docs {
            let left = Due.days(from: now, to: d.expiresOn, calendar: calendar)
            lines.append(DueLine(label: d.label.uppercased(), urgency: Due.document(expiresOn: d.expiresOn, now: now, calendar: calendar).urgency,
                                 amount: abs(left), unit: unit(abs(left)), target: d.id.map { "doc/\($0)" }))
        }
        // Within one urgency: the task furthest through its interval, then the document expiring first.
        return lines.sorted { ($0.urgency, -$0.progress, $0.amount) < ($1.urgency, -$1.progress, $1.amount) }
    }

    /// Fixed priority, highest wins (decision 91): riding, overdue, logs to complete, ride recap,
    /// due soon, new best, parked, then the next thing due.
    func state(at now: Date, calendar: Calendar = .current) -> WidgetState {
        if let live { return .riding(live) }
        let lines = dueLines(at: now, calendar: calendar)
        if let line = lines.first, line.urgency == .overdue { return .due(line) }
        if drafts > 0 { return .drafts(drafts) }
        let last = rides.first
        if let last, (0..<Self.recapForS).contains(now.timeIntervalSince(last.endedAt)) { return .recap(last) }
        if let line = lines.first, line.urgency == .soon { return .due(line) }
        if let best, (0..<Self.bestForS).contains(now.timeIntervalSince(best.at)) { return .best(best) }
        if let last {
            let days = Due.days(from: last.endedAt, to: now, calendar: calendar)
            if days >= Self.parkedAfterDays { return .parked(days: days, last: last) }
        }
        if let line = lines.first { return .due(line) }
        return .empty(hasBike ? "ALL CLEAR" : "ADD YOUR BIKE")
    }

    /// When the state can change with nobody touching the app: the recap and the new best
    /// expire, and each midnight moves the day counts.
    func changeDates(after now: Date, calendar: Calendar = .current) -> [Date] {
        var dates: [Date] = []
        if let last = rides.first { dates.append(last.endedAt.addingTimeInterval(Self.recapForS)) }
        if let best { dates.append(best.at.addingTimeInterval(Self.bestForS)) }
        if let loggedAt { dates.append(loggedAt.addingTimeInterval(Self.loggedForS)) }
        let today = calendar.startOfDay(for: now)
        dates += (1...7).compactMap { calendar.date(byAdding: .day, value: $0, to: today) }
        return dates.filter { $0 > now }.sorted()
    }

    /// Kilometres ridden in the ISO week holding `now`, like the Today screen's week.
    func weekKm(at now: Date) -> Int {
        guard let week = Calendar(identifier: .iso8601).dateInterval(of: .weekOfYear, for: now) else { return 0 }
        return Int(rides.filter { week.contains($0.endedAt) }.reduce(0) { $0 + $1.km }.rounded())
    }
}

extension WidgetSnapshot {
    static let group = "group.com.arnavparmaj.trace"
    private static let key = "widgetSnapshot"

    static func load() -> WidgetSnapshot {
        UserDefaults(suiteName: group)?.data(forKey: key)
            .flatMap { try? JSONDecoder().decode(WidgetSnapshot.self, from: $0) } ?? WidgetSnapshot()
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults(suiteName: Self.group)?.set(data, forKey: Self.key)
    }
}
