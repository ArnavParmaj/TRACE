import Foundation
import Testing
@testable import TRACE

/// The widget shows one thing at a time; these pin the priority ladder (decision 91).
struct WidgetStateTests {
    private let now = Date(timeIntervalSince1970: 1_794_700_000)
    private let day = 86_400.0
    private var utc: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = .gmt; return c }

    /// A bike with chain lube 120 km away, insurance far off, last ride two days ago.
    private var base: WidgetSnapshot {
        var s = WidgetSnapshot(hasBike: true, odometerKm: 1782)
        s.tasks = [.init(label: "Chain lube", lastDoneOdoKm: 1402, intervalKm: 500)]
        s.docs = [.init(label: "Insurance", expiresOn: now.addingTimeInterval(200 * day))]
        s.rides = [.init(endedAt: now.addingTimeInterval(-2 * day), km: 31.4, minutes: 88, topKph: 84)]
        return s
    }

    private func state(_ s: WidgetSnapshot) -> WidgetState { s.state(at: now, calendar: utc) }

    @Test func defaultShowsTheNextThingDue() {
        #expect(state(base) == .due(DueLine(label: "CHAIN LUBE", urgency: .ok, amount: 120, unit: "KM", progress: 0.76)))
        #expect(state(WidgetSnapshot()) == .empty("ADD YOUR BIKE"))
        #expect(state(WidgetSnapshot(hasBike: true)) == .empty("ALL CLEAR"))
    }

    @Test func snoozedTaskLeavesTheWidgetUntilMidnightOfItsLastDay() {
        var s = base
        s.odometerKm = 1942                                                    // chain lube overdue
        s.tasks[0].snoozedUntil = now.addingTimeInterval(3 * day)
        #expect(!s.dueLines(at: now, calendar: utc).contains { $0.label == "CHAIN LUBE" })
        s.tasks[0].snoozedUntil = now.addingTimeInterval(-1)
        #expect(s.dueLines(at: now, calendar: utc).first?.label == "CHAIN LUBE")
    }

    @Test func lockScreenLinesNameTheStateInWords() {
        var s = base
        #expect(LockLines(state(s)) == LockLines(.due(DueLine(label: "CHAIN LUBE", urgency: .ok, amount: 120, unit: "KM"))))
        #expect(LockLines(state(s)).kicker == "NEXT DUE" && LockLines(state(s)).detail == "120 KM LEFT" && LockLines(state(s)).big == "120")
        s.odometerKm = 1942
        #expect(LockLines(state(s)).kicker == "OVERDUE" && LockLines(state(s)).detail == "40 KM OVER")   // told in words: the lock screen has no red
        s.drafts = 2
        s.tasks[0].snoozedUntil = now.addingTimeInterval(day)   // snoozed: the overdue task steps aside for the logs
        #expect(LockLines(state(s)).big == "2" && LockLines(state(s)).unit == "LOGS")
    }

    @Test func everythingTrueAtOnceFollowsTheLadder() {
        var s = base
        s.odometerKm = 1942                                                    // chain lube 40 km over
        s.docs[0].expiresOn = now.addingTimeInterval(12 * day)                 // insurance due soon
        s.drafts = 2
        s.rides[0].endedAt = now.addingTimeInterval(-1800)                     // rode half an hour ago
        s.best = .init(title: "LONGEST RIDE", value: "62", unit: "KM", at: s.rides[0].endedAt)
        s.live = .init(startedAt: now, clockStart: now)

        #expect(state(s) == .riding(s.live!))
        s.live = nil
        #expect(state(s) == .due(DueLine(label: "CHAIN LUBE", urgency: .overdue, amount: 40, unit: "KM", progress: 1.08)))
        s.odometerKm = 1782
        #expect(state(s) == .drafts(2))
        s.drafts = 0
        #expect(state(s) == .recap(s.rides[0]))
        s.rides[0].endedAt = now.addingTimeInterval(-4 * 3600)                 // recap has expired
        #expect(state(s) == .due(DueLine(label: "INSURANCE", urgency: .soon, amount: 12, unit: "DAYS")))
        s.docs[0].expiresOn = now.addingTimeInterval(200 * day)
        #expect(state(s) == .best(s.best!))
        s.best = nil
        s.rides[0].endedAt = now.addingTimeInterval(-9 * day)
        #expect(state(s) == .parked(days: 9, last: s.rides[0]))
    }

    @Test func changesByItselfWhenRecapEndsAndAtMidnight() {
        var s = base
        s.rides[0].endedAt = now.addingTimeInterval(-1800)
        let dates = s.changeDates(after: now, calendar: utc)
        let recapEnds = s.rides[0].endedAt.addingTimeInterval(WidgetSnapshot.recapForS)
        #expect(dates.contains(recapEnds))
        #expect(dates == dates.sorted() && dates.allSatisfy { $0 > now })
        #expect(dates.filter { utc.startOfDay(for: $0) == $0 }.count == 7)     // the next 7 midnights
        #expect(s.state(at: recapEnds, calendar: utc) != .recap(s.rides[0]))
    }

    @Test func weekTotalCountsOnlyThisWeek() {
        var s = base
        s.rides = [.init(endedAt: now, km: 20.4, minutes: 30, topKph: 60),
                   .init(endedAt: now.addingTimeInterval(-8 * day), km: 50, minutes: 60, topKph: 70)]
        #expect(s.weekKm(at: now) == 20)
    }

    @Test func aTapOpensTheScreenThePanelShows() {
        let task = UUID(), ride = UUID()
        var s = base
        s.tasks[0].id = task
        s.rides[0].id = ride
        #expect(WidgetLink.panel(state(s)).absoluteString == "trace://task/\(task)")
        s.drafts = 1
        #expect(WidgetLink.panel(state(s)).absoluteString == "trace://drafts")
        s.drafts = 0
        s.rides[0].endedAt = now.addingTimeInterval(-600)
        #expect(WidgetLink.panel(state(s)).absoluteString == "trace://trip/\(ride)")

        let parsed = WidgetLink.parse(URL(string: "trace://task/\(task)")!)
        #expect(parsed?.link == .task && parsed?.id == task)
        #expect(WidgetLink.parse(URL(string: "trace://start")!)?.id == nil)
        #expect(WidgetLink.parse(URL(string: "trace://nonsense")!) == nil)
    }

    @Test func logButtonSaysLoggedForAFewSeconds() {
        var s = base
        s.loggedAt = now
        #expect(s.justLogged(at: now.addingTimeInterval(2)))
        #expect(!s.justLogged(at: now.addingTimeInterval(WidgetSnapshot.loggedForS)))
        #expect(s.changeDates(after: now, calendar: utc).contains(now.addingTimeInterval(WidgetSnapshot.loggedForS)))
    }
}
