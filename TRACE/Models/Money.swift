import Foundation
import SwiftData

enum ExpenseCategory: String, Codable, CaseIterable, Sendable {
    case fuel, food, parts, parking, other   // decision 37
}

/// Money never leaves the device (invariant 1). `syncScope` has no setter path
/// and the type lives in the local-only store, so no sync pass can reach it.
@Model
final class Expense: SyncRecord {
    var id = UUID()
    var ownerID = UUID.unowned
    var createdAt = Date.now
    var updatedAt = Date.now
    var deletedAt: Date?
    private(set) var syncScope = SyncScope.localOnly

    var occurredAt = Date.now
    /// Paise. Never Double (invariant 2).
    var amountMinor = 0
    var currencyCode = "INR"
    var category = ExpenseCategory.other
    var note: String?
    /// Set by the fusion rule when a ride closes; user can detach.
    var rideID: UUID?
    var vehicleID: UUID?
    /// The service this paid for, if any. The event syncs; this link and the money don't.
    var serviceEventID: UUID?
    var odometerKm: Int?

    // Fuel only. Litres are a quantity, not money, so Double is fine.
    var litres: Double?
    var pricePerLitreMinor: Int?
    var isFullTank: Bool?

    init(amountMinor: Int, category: ExpenseCategory, occurredAt: Date = .now) {
        self.amountMinor = amountMinor
        self.category = category
        self.occurredAt = occurredAt
    }
}

enum CaptureKind: String, Codable, Sendable {
    case unclassified   // v1: a draft becomes an expense or is discarded (U5)
}

/// What one Action Button press writes. Ephemeral and local-only.
@Model
final class CaptureDraft: SyncRecord {
    var id = UUID()
    var ownerID = UUID.unowned
    var createdAt = Date.now
    var updatedAt = Date.now
    var deletedAt: Date?
    private(set) var syncScope = SyncScope.localOnly

    var kind = CaptureKind.unclassified
    var capturedAt = Date.now
    var lat: Double?
    var lon: Double?
    var rideID: UUID?
    var rawValue: String?

    init(capturedAt: Date = .now) {
        self.capturedAt = capturedAt
    }
}
