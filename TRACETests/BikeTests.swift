import Foundation
import SwiftData
import Testing
@testable import TRACE

private struct TestUser: CurrentUser { let ownerID = UUID() }

private let cal: Calendar = {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "Asia/Kolkata")!
    return c
}()
private func day(_ d: Int, _ hour: Int = 12) -> Date {
    cal.date(from: DateComponents(year: 2026, month: 10, day: d, hour: hour))!
}

@Suite struct DueTests {
    @Test(arguments: [
        (12_000, Urgency.ok, "OK"),
        (12_460, .soon, "DUE IN 40 KM"),        // ≤ 15% of 500 left
        (12_500, .soon, "DUE IN 0 KM"),
        (12_580, .overdue, "OVERDUE BY 80 KM"),
    ])
    func byKm(odo: Int, urgency: Urgency, text: String) {
        let s = Due.service(lastDoneOdoKm: 12_000, lastDoneAt: nil, intervalKm: 500, intervalDays: nil,
                            odometerKm: odo, now: day(1), calendar: cal)
        #expect(s.urgency == urgency)
        #expect(s.text == text)
    }

    /// U4: a wider due-soon share in Settings turns the same reading amber earlier.
    @Test func soonShareIsTunable() {
        let at15 = Due.service(lastDoneOdoKm: 12_000, lastDoneAt: nil, intervalKm: 500, intervalDays: nil,
                               odometerKm: 12_380, now: day(1), calendar: cal)
        let at30 = Due.service(lastDoneOdoKm: 12_000, lastDoneAt: nil, intervalKm: 500, intervalDays: nil,
                               odometerKm: 12_380, now: day(1), soonShare: 0.3, calendar: cal)
        #expect(at15.urgency == .ok && at30.urgency == .soon)
        #expect(Due.soonDays(100, share: 0.05) == 5 && Due.soonDays(100) == 14)
    }

    @Test func byDaysAndWorstWins() {
        // Done Oct 1, 10-day interval → due Oct 11.
        let soon = Due.service(lastDoneOdoKm: nil, lastDoneAt: day(1), intervalKm: nil, intervalDays: 10,
                               odometerKm: 0, now: day(10), calendar: cal)
        #expect(soon.text == "DUE IN 1 DAY")   // 15% of 10 → 2 days window
        let over = Due.service(lastDoneOdoKm: 100, lastDoneAt: day(1), intervalKm: 5_000, intervalDays: 10,
                               odometerKm: 200, now: day(14), calendar: cal)
        #expect(over.urgency == .overdue && over.text == "OVERDUE BY 3 DAYS")
    }

    @Test func unknownWithoutHistory() {
        let s = Due.service(lastDoneOdoKm: nil, lastDoneAt: nil, intervalKm: 500, intervalDays: nil,
                            odometerKm: 900, now: day(1), calendar: cal)
        #expect(s.urgency == .unknown)
    }

    @Test(arguments: [
        (20, Urgency.overdue, "EXPIRED 3 DAYS AGO"),
        (23, .soon, "EXPIRES TODAY"),
        (24, .soon, "1 DAY"),
    ])
    func document(expiresDay: Int, urgency: Urgency, text: String) {
        let s = Due.document(expiresOn: day(expiresDay, 0), now: day(23, 22), calendar: cal)
        #expect(s.urgency == urgency && s.text == text)
    }
}

@Suite struct ReminderPlanTests {
    @Test func documentLeadsAndExpiryDayInFutureOnly() {
        let puc = VehicleDocument(kind: .puc, expiresOn: day(24))
        puc.reminderDaysBefore = [30, 7, 1]
        let plan = Reminders.plan(documents: [puc], tasks: [], now: day(23, 10), calendar: cal)
        // 1-day lead (Oct 23 9:00) has passed; expiry day 9:00 remains.
        #expect(plan.map(\.body) == ["PUC expires today"])
        #expect(plan.first?.fireAt == cal.date(from: DateComponents(year: 2026, month: 10, day: 24, hour: 9)))
    }

    @Test func dayIntervalTaskGetsSoonAndOverdue() {
        let task = ServiceTask(vehicleID: UUID(), kind: .chainLube, label: "Chain lube")
        task.intervalDays = 10
        task.lastDoneAt = day(1)
        let plan = Reminders.plan(documents: [], tasks: [task], now: day(1), calendar: cal)
        #expect(plan.map(\.body) == ["Chain lube due in 2 days", "Chain lube overdue"])
    }
}

@MainActor
@Suite struct GarageTests {
    let container = try! Store.container(inMemory: true)
    fileprivate let user = TestUser()
    var garage: Garage { Garage(context: container.mainContext, user: user) }

    /// S16: only the first bike starts primary; picking another moves the flag, never two at once.
    @Test func onePrimaryBike() throws {
        let cb = try garage.addBike(name: "CB350", registration: nil, odometerKm: 0)
        let him = try garage.addBike(name: "Himalayan", registration: nil, odometerKm: 0)
        #expect(cb.isPrimary && !him.isPrimary)
        try garage.makePrimary(him)
        #expect(!cb.isPrimary && him.isPrimary)
        #expect(try garage.bike()?.id == him.id)
        #expect(try garage.bikes().filter(\.isPrimary).count == 1)
    }

    @Test func odometerRefusesGoingDownUnlessConfirmed() throws {
        let bike = try garage.addBike(name: "CB350", registration: nil, odometerKm: 12_480)
        #expect(throws: Garage.Failure.odometerWentDown) { try garage.setOdometer(bike, km: 12_000) }
        try garage.setOdometer(bike, km: 100, allowLower: true)
        #expect(bike.odometerKm == 100)
    }

    @Test func tripsAndSuggestionSumRidesSinceReset() throws {
        let bike = try garage.addBike(name: "CB350", registration: nil, odometerKm: 1_000, at: day(1))
        let rides = Repository<Ride>(context: container.mainContext, user: user)
        for (d, m) in [(2, 30_000), (5, 12_400)] {
            let r = Ride(vehicleID: bike.id, startedAt: day(d))
            r.distanceM = m
            rides.insert(r)
        }
        try rides.save()
        try garage.resetTrip(bike, .b, at: day(3))
        #expect(try garage.tripKm(bike, .a) == 42.4)
        #expect(try garage.tripKm(bike, .b) == 12.4)
        #expect(try garage.odometerSuggestion(bike) == 1_042)
    }

    @Test func markDoneLogsEventKeepsMoneyLocalAndRaisesOdo() throws {
        let bike = try garage.addBike(name: "CB350", registration: nil, odometerKm: 12_000)
        let task = ServiceTask(vehicleID: bike.id, kind: .oilChange, label: "Oil change")
        task.intervalKm = 3_000
        try garage.save(task, for: bike)
        let event = try garage.markDone(task, bike: bike, odometerKm: 12_480, costMinor: 85_000)
        #expect(task.lastDoneOdoKm == 12_480 && bike.odometerKm == 12_480)
        let history = try garage.history(task)
        #expect(history.count == 1 && history[0].event.id == event.id && history[0].costMinor == 85_000)
        let expense = try #require(try Repository<Expense>(context: container.mainContext, user: user).all().first)
        #expect(expense.serviceEventID == event.id && expense.syncScope == .localOnly)
        #expect(garage.due(task, bike).urgency == .ok)
    }

    @Test func dueItemsKeepsOnlyUrgentMostUrgentFirst() throws {
        let bike = try garage.addBike(name: "CB350", registration: nil, odometerKm: 12_580)
        let chain = ServiceTask(vehicleID: bike.id, kind: .chainLube, label: "Chain lube")
        chain.intervalKm = 500
        chain.lastDoneOdoKm = 12_000
        try garage.save(chain, for: bike)
        try garage.save(VehicleDocument(kind: .insurance, expiresOn: .now.addingTimeInterval(86_400 * 10)))
        try garage.save(VehicleDocument(kind: .rc, expiresOn: .now.addingTimeInterval(86_400 * 3_000)))
        #expect(try garage.dueItems().map(\.label) == ["Chain lube", "Insurance"])
    }
}
