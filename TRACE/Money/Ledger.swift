import Foundation
import SwiftData

/// km/L for one full-tank-to-full-tank interval, closed by the fill `closingID`.
struct Economy: Equatable, Sendable {
    let at: Date
    let km: Int
    let litres: Double
    let closingID: UUID
    var kmPerL: Double { Double(km) / litres }
}

/// Expenses, the fusion rule and km/L. Money stays local-only (invariant 1).
@MainActor
struct Ledger {
    private let expenses: Repository<Expense>
    private let rides: Repository<Ride>

    init(context: ModelContext, user: any CurrentUser) {
        expenses = Repository(context: context, user: user)
        rides = Repository(context: context, user: user)
    }

    // MARK: Fusion (DATA-MODEL.md)

    /// Attaches every unattached expense inside the ride's time span. Reversible: `detach`.
    @discardableResult
    func fuse(_ ride: Ride) throws -> [Expense] {
        guard let end = ride.endedAt else { return [] }
        let start = ride.startedAt
        let found = try expenses.all().filter { $0.rideID == nil && $0.occurredAt >= start && $0.occurredAt <= end }
        for e in found { expenses.update(e) { $0.rideID = ride.id } }
        try expenses.save()
        return found
    }

    /// The finished ride whose span contains `time`, if any. A ride still recording is fused when it closes.
    func ride(containing time: Date) throws -> Ride? {
        try rides.finished().first { r in r.endedAt.map { r.startedAt <= time && time <= $0 } ?? false }
    }

    func attach(_ e: Expense, to ride: Ride) throws {
        expenses.update(e) { $0.rideID = ride.id }
        try expenses.save()
    }

    func detach(_ e: Expense) throws {
        expenses.update(e) { $0.rideID = nil }
        try expenses.save()
    }

    /// A deleted ride gives its expenses back, so they don't point at a tombstone.
    func detachAll(from rideID: UUID) throws {
        for e in try attached(to: rideID) { expenses.update(e) { $0.rideID = nil } }
        try expenses.save()
    }

    // MARK: Reads

    /// Newest first.
    func all() throws -> [Expense] {
        try expenses.all(sortBy: [SortDescriptor(\.occurredAt, order: .reverse)])
    }

    func entries(in span: DateInterval) throws -> [Expense] {
        try all().filter { span.contains($0.occurredAt) }
    }

    func attached(to rideID: UUID) throws -> [Expense] {
        Array(try all().filter { $0.rideID == rideID }.reversed())   // oldest first
    }

    /// Unattached expenses within a day of the ride, the likely ones to attach by hand.
    func attachable(to ride: Ride) throws -> [Expense] {
        let span = DateInterval(start: ride.startedAt.addingTimeInterval(-86_400),
                                end: (ride.endedAt ?? ride.startedAt).addingTimeInterval(86_400))
        return try entries(in: span).filter { $0.rideID == nil }
    }

    func totalsByRide() throws -> [UUID: Int] {
        try all().reduce(into: [:]) { sums, e in
            if let id = e.rideID { sums[id, default: 0] += e.amountMinor }
        }
    }

    func ride(_ id: UUID?) throws -> Ride? {
        guard let id else { return nil }
        return try rides.find(id)
    }

    // MARK: Writes

    @discardableResult
    func add(category: ExpenseCategory, amountMinor: Int, at time: Date, litres: Double? = nil,
             isFullTank: Bool? = nil, odometerKm: Int? = nil, note: String? = nil) throws -> Expense {
        let e = Expense(amountMinor: amountMinor, category: category, occurredAt: time)
        e.fill(category: category, amountMinor: amountMinor, litres: litres, isFullTank: isFullTank,
               odometerKm: odometerKm, note: note)
        e.rideID = try ride(containing: time)?.id   // fusion for entries added after the ride closed
        expenses.insert(e)
        try expenses.save()
        return e
    }

    func update(_ e: Expense, category: ExpenseCategory, amountMinor: Int, at time: Date, litres: Double? = nil,
                isFullTank: Bool? = nil, odometerKm: Int? = nil, note: String? = nil) throws {
        // A new time re-runs fusion; the same time keeps the rider's own attach or detach.
        let rideID = time == e.occurredAt ? e.rideID : try ride(containing: time)?.id
        expenses.update(e) {
            $0.occurredAt = time
            $0.rideID = rideID
            $0.fill(category: category, amountMinor: amountMinor, litres: litres, isFullTank: isFullTank,
                    odometerKm: odometerKm, note: note)
        }
        try expenses.save()
    }

    func delete(_ e: Expense) throws {
        expenses.softDelete(e)
        try expenses.save()
    }

    // MARK: km/L (decisions 26, 58)

    func economy() throws -> [Economy] { Self.economy(try all()) }

    /// Oldest first. Two fuel fills in a row, both full with odometer and litres, make one
    /// interval: km between them ÷ litres of the second. Any other fuel entry between them
    /// (a partial, or a fill missing odometer or litres) voids that interval: never a guess.
    /// shortcut: one bike assumed (capture doesn't set vehicleID); group by vehicle when a second bike is possible.
    nonisolated static func economy(_ all: [Expense]) -> [Economy] {
        let fills = all.filter { $0.category == .fuel }.sorted { $0.occurredAt < $1.occurredAt }
        var out: [Economy] = []
        for (prev, next) in zip(fills, fills.dropFirst()) {
            guard prev.isFullTank == true, next.isFullTank == true,
                  let a = prev.odometerKm, let b = next.odometerKm, b > a,
                  let litres = next.litres, litres > 0 else { continue }
            out.append(Economy(at: next.occurredAt, km: b - a, litres: litres, closingID: next.id))
        }
        return out
    }
}

extension Expense {
    /// Fuel fields only for fuel; price per litre is derived, never typed (decision 58).
    func fill(category: ExpenseCategory, amountMinor: Int, litres: Double?, isFullTank: Bool?,
              odometerKm: Int?, note: String?) {
        self.category = category
        self.amountMinor = amountMinor
        self.note = note
        let fuel = category == .fuel
        self.litres = fuel ? litres : nil
        self.pricePerLitreMinor = fuel ? Capture.pricePerLitreMinor(amountMinor: amountMinor, litres: litres) : nil
        self.isFullTank = fuel ? isFullTank : nil
        self.odometerKm = fuel ? odometerKm : nil
    }
}
