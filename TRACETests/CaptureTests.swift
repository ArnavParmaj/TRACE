import Foundation
import SwiftData
import Testing
@testable import TRACE

private struct TestUser: CurrentUser { let ownerID = UUID() }

@MainActor
@Suite struct CaptureTests {
    let container = try! Store.container(inMemory: true)
    fileprivate let user = TestUser()
    var capture: Capture { Capture(context: container.mainContext, user: user) }

    @Test func logWritesOwnedDraftWithPlace() throws {
        let at = Date(timeIntervalSince1970: 1_000)
        let draft = try capture.log(at: at, lat: 18.75, lon: 73.40)
        #expect(draft.ownerID == user.ownerID)
        #expect(draft.capturedAt == at)
        #expect(draft.lat == 18.75 && draft.lon == 73.40)
        #expect(draft.rideID == nil)   // no ride open
        #expect(try capture.pending().map(\.id) == [draft.id])
    }

    @Test func logLinksTheOpenRide() throws {
        let rides = Repository<Ride>(context: container.mainContext, user: user)
        let ride = Ride(vehicleID: UUID())
        ride.isRecording = true
        rides.insert(ride)
        try rides.save()
        #expect(try capture.log().rideID == ride.id)
    }

    @Test func pendingIsNewestFirstAndOwnerScoped() throws {
        let old = try capture.log(at: Date(timeIntervalSince1970: 1))
        let new = try capture.log(at: Date(timeIntervalSince1970: 2))
        _ = try Capture(context: container.mainContext, user: TestUser()).log()
        #expect(try capture.pending().map(\.id) == [new.id, old.id])
    }

    @Test func completeFuelPromotesDraftToExpense() throws {
        let draft = try capture.log(at: Date(timeIntervalSince1970: 500))
        draft.rideID = UUID()
        let expense = try capture.complete(draft, category: .fuel, amountMinor: 41_000,
                                           litres: 4.1, isFullTank: true, odometerKm: 12_480, note: "Shell")
        #expect(expense.ownerID == user.ownerID)
        #expect(expense.occurredAt == draft.capturedAt)   // time defaults to capture time
        #expect(expense.rideID == draft.rideID)
        #expect(expense.amountMinor == 41_000)
        #expect(expense.litres == 4.1 && expense.isFullTank == true && expense.odometerKm == 12_480)
        #expect(expense.pricePerLitreMinor == 10_000)   // ₹410 / 4.1 L = ₹100/L
        #expect(draft.deletedAt != nil)                 // tombstoned, not hard-deleted
        #expect(try capture.pending().isEmpty)
        let saved = try Repository<Expense>(context: container.mainContext, user: user).all()
        #expect(saved.map(\.id) == [expense.id])
    }

    @Test func nonFuelDropsFuelFields() throws {
        let draft = try capture.log()
        let expense = try capture.complete(draft, category: .food, amountMinor: 12_050,
                                           litres: 3, isFullTank: true, odometerKm: 1)
        #expect(expense.litres == nil && expense.pricePerLitreMinor == nil && expense.isFullTank == nil)
        #expect(expense.odometerKm == nil)
    }

    @Test func discardTombstonesDraft() throws {
        let draft = try capture.log()
        try capture.discard(draft)
        #expect(draft.deletedAt != nil)
        #expect(try capture.pending().isEmpty)
    }

    @Test func undoRestoresADiscardedDraft() throws {
        let draft = try capture.log()
        try capture.discard(draft)
        try capture.restore(draft)
        #expect(draft.deletedAt == nil)
        #expect(try capture.pending().map(\.id) == [draft.id])
    }

    @Test(arguments: [
        (41_000, 4.1, 10_000),     // exact
        (100_000, 3.0, 33_333),    // rounds down
        (20_000, 3.0, 6_667),      // rounds up
    ])
    func pricePerLitreRoundsToPaise(amount: Int, litres: Double, expected: Int) {
        #expect(Capture.pricePerLitreMinor(amountMinor: amount, litres: litres) == expected)
    }

    @Test func pricePerLitreNeedsPositiveLitres() {
        #expect(Capture.pricePerLitreMinor(amountMinor: 41_000, litres: 0) == nil)
        #expect(Capture.pricePerLitreMinor(amountMinor: 41_000, litres: nil) == nil)
    }
}
