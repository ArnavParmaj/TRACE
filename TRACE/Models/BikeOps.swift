import Foundation
import SwiftData

@Model
final class Vehicle: SyncRecord {
    var id = UUID()
    var ownerID = UUID.unowned
    var createdAt = Date.now
    var updatedAt = Date.now
    var deletedAt: Date?
    var syncScope = SyncScope.syncable

    var name = ""
    var make: String?
    var model: String?
    var year: Int?
    var registrationNumber: String?
    /// Manual and authoritative; GPS only suggests (decision 24).
    var odometerKm = 0
    var tankCapacityL: Double?
    var isPrimary = false

    init(name: String, odometerKm: Int = 0) {
        self.name = name
        self.odometerKm = odometerKm
    }
}

enum ServiceKind: String, Codable, CaseIterable, Sendable {
    case chainLube, oilChange, brakePads, tyres, custom
}

/// Due state is computed from the odometer and dates, never stored (invariant 6).
@Model
final class ServiceTask: SyncRecord {
    var id = UUID()
    var ownerID = UUID.unowned
    var createdAt = Date.now
    var updatedAt = Date.now
    var deletedAt: Date?
    var syncScope = SyncScope.syncable

    var vehicleID = UUID.unowned
    var kind = ServiceKind.custom
    var label = ""
    var intervalKm: Int?
    var intervalDays: Int?
    var lastDoneOdoKm: Int?
    var lastDoneAt: Date?
    var isActive = true

    init(vehicleID: UUID, kind: ServiceKind, label: String) {
        self.vehicleID = vehicleID
        self.kind = kind
        self.label = label
    }
}

/// Syncs. If it has a cost, a paired local-only Expense holds the money.
@Model
final class ServiceEvent: SyncRecord {
    var id = UUID()
    var ownerID = UUID.unowned
    var createdAt = Date.now
    var updatedAt = Date.now
    var deletedAt: Date?
    var syncScope = SyncScope.syncable

    var vehicleID = UUID.unowned
    var taskID: UUID?
    var performedAt = Date.now
    var odometerKm = 0
    var costMinor: Int?
    var notes: String?

    init(vehicleID: UUID, odometerKm: Int, performedAt: Date = .now) {
        self.vehicleID = vehicleID
        self.odometerKm = odometerKm
        self.performedAt = performedAt
    }
}

enum DocumentKind: String, Codable, CaseIterable, Sendable {
    case insurance, puc, rc, drivingLicence, other
}

@Model
final class VehicleDocument: SyncRecord {
    var id = UUID()
    var ownerID = UUID.unowned
    var createdAt = Date.now
    var updatedAt = Date.now
    var deletedAt: Date?
    var syncScope = SyncScope.syncable

    var vehicleID: UUID?
    var kind = DocumentKind.other
    var identifier: String?
    var issuedOn: Date?
    var expiresOn = Date.now
    var reminderDaysBefore = [30, 7, 1]
    /// Local file in the app container. Never synced, never in Photos.
    var attachmentPath: String?

    init(kind: DocumentKind, expiresOn: Date) {
        self.kind = kind
        self.expiresOn = expiresOn
    }
}
