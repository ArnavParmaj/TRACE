import Foundation

enum Urgency: Int, Comparable {
    case overdue, soon, ok, unknown
    static func < (a: Urgency, b: Urgency) -> Bool { a.rawValue < b.rawValue }
}

struct DueStatus: Equatable {
    var urgency: Urgency
    var text: String
    /// Share of the interval used, 0…1+. Nil for documents and unknown tasks.
    var progress: Double?
}

/// Due state is computed on render from the odometer and today, never stored (invariant 6).
enum Due {
    /// A document is "soon" inside its first default reminder (decision 61).
    static let documentSoonDays = 30

    static func service(lastDoneOdoKm: Int?, lastDoneAt: Date?, intervalKm: Int?, intervalDays: Int?,
                        odometerKm: Int, now: Date, calendar: Calendar = .current) -> DueStatus {
        var kmLeft: Int?, kmUsed: Double?, kmSoon = false
        if let interval = intervalKm, interval > 0, let last = lastDoneOdoKm {
            let left = last + interval - odometerKm
            kmLeft = left
            kmUsed = Double(odometerKm - last) / Double(interval)
            kmSoon = Double(left) <= Double(interval) * 0.15
        }
        var daysLeft: Int?, daysUsed: Double?, daysSoon = false
        if let interval = intervalDays, interval > 0, let last = lastDoneAt,
           let dueDay = calendar.date(byAdding: .day, value: interval, to: last) {
            let left = days(from: now, to: dueDay, calendar: calendar)
            daysLeft = left
            daysUsed = Double(interval - left) / Double(interval)
            daysSoon = left <= soonDays(interval)
        }
        guard kmLeft != nil || daysLeft != nil else { return DueStatus(urgency: .unknown, text: "SET LAST DONE", progress: nil) }
        let progress = max(kmUsed ?? 0, daysUsed ?? 0)

        if let k = kmLeft, k < 0 { return DueStatus(urgency: .overdue, text: "OVERDUE BY \(km(-k)) KM", progress: progress) }
        if let d = daysLeft, d < 0 { return DueStatus(urgency: .overdue, text: "OVERDUE BY \(dayCount(-d))", progress: progress) }
        if kmSoon, let k = kmLeft { return DueStatus(urgency: .soon, text: "DUE IN \(km(k)) KM", progress: progress) }
        if daysSoon, let d = daysLeft {
            return DueStatus(urgency: .soon, text: d == 0 ? "DUE TODAY" : "DUE IN \(dayCount(d))", progress: progress)
        }
        return DueStatus(urgency: .ok, text: "OK", progress: progress)
    }

    static func document(expiresOn: Date, now: Date, calendar: Calendar = .current) -> DueStatus {
        let d = days(from: now, to: expiresOn, calendar: calendar)
        let status: (Urgency, String) = switch d {
        case ..<0: (.overdue, "EXPIRED \(dayCount(-d)) AGO")
        case 0: (.soon, "EXPIRES TODAY")
        case ...documentSoonDays: (.soon, dayCount(d))
        case ...60: (.ok, dayCount(d))
        default: (.ok, expiresOn.formatted(.dateTime.month(.abbreviated).year()).uppercased())
        }
        return DueStatus(urgency: status.0, text: status.1, progress: nil)
    }

    /// "Soon" for a day interval: 15% of it, capped at 14 days (S02), at least 1.
    static func soonDays(_ interval: Int) -> Int { min(14, max(1, Int((Double(interval) * 0.15).rounded(.up)))) }

    /// Whole calendar days between two dates, by local midnight.
    static func days(from: Date, to: Date, calendar: Calendar = .current) -> Int {
        calendar.dateComponents([.day], from: calendar.startOfDay(for: from), to: calendar.startOfDay(for: to)).day ?? 0
    }

    private static func km(_ value: Int) -> String { value.formatted() }
    private static func dayCount(_ n: Int) -> String { n == 1 ? "1 DAY" : "\(n) DAYS" }
}
