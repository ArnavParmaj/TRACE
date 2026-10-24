import Foundation
import SwiftData
import Testing
@testable import TRACE

private let t0 = Date(timeIntervalSince1970: 1_800_000_000)

@MainActor
@Suite struct LedgerTests {
    let container = try! Store.container(inMemory: true)
    let user = RiderUser()
    var ledger: Ledger { Ledger(context: container.mainContext, user: user) }

    private func closedRide(from: TimeInterval, to: TimeInterval) throws -> Ride {
        let rides = Repository<Ride>(context: container.mainContext, user: user)
        let ride = Ride(vehicleID: UUID(), startedAt: t0.addingTimeInterval(from))
        ride.endedAt = t0.addingTimeInterval(to)
        rides.insert(ride)
        try rides.save()
        return ride
    }

    private func spend(_ rupees: Int, at s: TimeInterval, _ c: ExpenseCategory = .food) throws -> Expense {
        try ledger.add(category: c, amountMinor: rupees * 100, at: t0.addingTimeInterval(s))
    }

    /// M4 exit in miniature: two expenses fuse with the right total; detaching one frees it.
    @Test func fusionAttachesInsideTheRideOnly() throws {
        let ride = try closedRide(from: 0, to: 3_600)
        let fuel = try spend(410, at: 600, .fuel)
        let chai = try spend(70, at: 3_600)                 // the end instant counts
        let before = try spend(50, at: -1)
        let otherRide = try spend(30, at: 1_200)
        let elsewhere = try closedRide(from: 5_000, to: 6_000)
        try ledger.attach(otherRide, to: elsewhere)          // already attached: left alone
        let gone = try spend(99, at: 900)
        try ledger.delete(gone)

        let fused = try ledger.fuse(ride)
        #expect(Set(fused.map(\.id)) == [fuel.id, chai.id])
        #expect(try ledger.attached(to: ride.id).map(\.id) == [fuel.id, chai.id])
        #expect(try ledger.totalsByRide()[ride.id] == 48_000)
        #expect(before.rideID == nil && otherRide.rideID == elsewhere.id)

        try ledger.detach(chai)
        #expect(chai.rideID == nil)
        #expect(try ledger.totalsByRide()[ride.id] == 41_000)
        #expect(try ledger.attachable(to: ride).map(\.id).contains(chai.id))
    }

    @Test func closingARideFusesAndDeletingItDetaches() throws {
        let rec = RideRecorder(context: container.mainContext, user: user, sensors: StubSensors(), lookUpPlaces: false)
        rec.start(vehicleID: UUID(), at: t0)
        let fuel = try spend(410, at: 30, .fuel)
        for s in 0...60 { rec.ingest(Fix(time: t0.addingTimeInterval(Double(s)), lat: 19 + Double(s) * 1e-4, lon: 72.8, speedMps: 10)) }
        rec.stop()
        let ride = try #require(rec.lastClosed)
        #expect(fuel.rideID == ride.id)

        rec.delete(ride)
        #expect(fuel.rideID == nil)
    }

    @Test func editingClearsFuelFieldsOffFuel() throws {
        let e = try ledger.add(category: .fuel, amountMinor: 41_000, at: t0, litres: 4.1, isFullTank: true, odometerKm: 12_480)
        #expect(e.pricePerLitreMinor == 10_000)
        try ledger.update(e, category: .food, amountMinor: 7_000, at: t0, litres: 4.1, isFullTank: true, odometerKm: 1)
        #expect(e.litres == nil && e.isFullTank == nil && e.odometerKm == nil && e.pricePerLitreMinor == nil)
        #expect(e.amountMinor == 7_000)
    }

    /// Hand calc: 12,000 → 12,140 km on 4.0 L = 35.0 km/L; 12,140 → 12,420 on 8.0 L = 35.0.
    /// The partial voids both intervals it sits in; a fill without odometer is skipped too.
    @Test func kmPerLitreOnlyBetweenConsecutiveFullFills() throws {
        func fill(_ s: TimeInterval, odo: Int?, litres: Double?, full: Bool) -> Expense {
            let e = Expense(amountMinor: 40_000, category: .fuel, occurredAt: t0.addingTimeInterval(s))
            e.odometerKm = odo
            e.litres = litres
            e.isFullTank = full
            return e
        }
        let a = fill(0, odo: 12_000, litres: 9, full: true)
        let b = fill(10, odo: 12_140, litres: 4, full: true)
        let c = fill(20, odo: 12_420, litres: 8, full: true)
        let partial = fill(30, odo: 12_500, litres: 2, full: false)
        let d = fill(40, odo: 12_700, litres: 7, full: true)
        let noOdo = fill(50, odo: nil, litres: 6, full: true)
        let e = fill(60, odo: 13_000, litres: 9, full: true)
        let food = Expense(amountMinor: 100, category: .food, occurredAt: t0.addingTimeInterval(15))

        let out = Ledger.economy([e, noOdo, d, partial, c, b, a, food])
        #expect(out.map(\.closingID) == [b.id, c.id])
        #expect(out.map(\.kmPerL) == [35, 35])
        #expect(Ledger.economy([a]).isEmpty)   // W6: one fill is no number, not 0.0
    }
}
