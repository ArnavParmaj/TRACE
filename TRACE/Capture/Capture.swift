import Foundation
import SwiftData

extension Notification.Name {
    /// Posted after a draft is logged, so an open Today screen reloads its queue.
    static let draftCaptured = Notification.Name("draftCaptured")
}

/// The capture queue: one press writes a draft (invariant 7), the app later turns it
/// into an expense (S08) or discards it.
@MainActor
struct Capture {
    private let drafts: Repository<CaptureDraft>
    private let rides: Repository<Ride>
    private let expenses: Repository<Expense>

    init(context: ModelContext, user: any CurrentUser) {
        drafts = Repository(context: context, user: user)
        rides = Repository(context: context, user: user)
        expenses = Repository(context: context, user: user)
    }

    /// Never waits on anything: time, last known place, the open ride if any.
    @discardableResult
    func log(at time: Date = .now, lat: Double? = nil, lon: Double? = nil) throws -> CaptureDraft {
        let draft = CaptureDraft(capturedAt: time)
        draft.lat = lat
        draft.lon = lon
        draft.rideID = try rides.openRide()?.id
        drafts.insert(draft)
        try drafts.save()
        NotificationCenter.default.post(name: .draftCaptured, object: nil)
        return draft
    }

    /// Drafts waiting to be completed, newest first.
    func pending() throws -> [CaptureDraft] {
        try drafts.all(sortBy: [SortDescriptor(\.capturedAt, order: .reverse)])
    }

    /// Promotes the draft to an expense at the draft's capture time.
    @discardableResult
    func complete(_ draft: CaptureDraft, category: ExpenseCategory, amountMinor: Int,
                  litres: Double? = nil, isFullTank: Bool? = nil, odometerKm: Int? = nil,
                  note: String? = nil) throws -> Expense {
        let expense = Expense(amountMinor: amountMinor, category: category, occurredAt: draft.capturedAt)
        expense.rideID = draft.rideID
        expense.fill(category: category, amountMinor: amountMinor, litres: litres, isFullTank: isFullTank,
                     odometerKm: odometerKm, note: note)
        expenses.insert(expense)
        drafts.softDelete(draft)
        try expenses.save()
        return expense
    }

    func discard(_ draft: CaptureDraft) throws {
        drafts.softDelete(draft)
        try drafts.save()
    }

    /// Paise per litre, rounded to the nearest paisa. Nil without a positive litre count.
    nonisolated static func pricePerLitreMinor(amountMinor: Int, litres: Double?) -> Int? {
        guard let litres, litres > 0 else { return nil }
        return Int((Double(amountMinor) / litres).rounded())
    }
}
