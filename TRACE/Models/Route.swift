import Foundation
import SwiftData

@Model
final class Ride: SyncRecord {
    var id = UUID()
    var ownerID = UUID.unowned
    var createdAt = Date.now
    var updatedAt = Date.now
    var deletedAt: Date?
    var syncScope = SyncScope.syncable

    var vehicleID = UUID.unowned
    var startedAt = Date.now
    var endedAt: Date?
    var distanceM = 0
    var movingDurationS = 0
    var elapsedDurationS = 0
    var climbM = 0
    var avgSpeedKph = 0.0
    var maxSpeedKph = 0.0
    var startPlaceName: String?
    var endPlaceName: String?
    var odoStartKm: Int?
    var odoEndKm: Int?
    /// Compressed route for map replay, written when the ride closes.
    var encodedPolyline = Data()
    var isRecording = false
    /// Set while the rider has paused; GPS is off. Survives a kill (decision 51).
    var pausedAt: Date?
    /// Total paused time; excluded from moving time and not a stop.
    var pausedDurationS = 0

    init(vehicleID: UUID, startedAt: Date = .now) {
        self.vehicleID = vehicleID
        self.startedAt = startedAt
    }
}

/// Full-resolution GPS sample. The only unbounded table (retention: decision 27).
@Model
final class RouteSample: SyncRecord {
    var id = UUID()
    var ownerID = UUID.unowned
    var createdAt = Date.now
    var updatedAt = Date.now
    var deletedAt: Date?
    var syncScope = SyncScope.syncable

    var rideID = UUID.unowned
    var timestamp = Date.now
    var lat = 0.0
    var lon = 0.0
    var altitudeM = 0.0
    var speedMps = 0.0
    var horizontalAccuracyM = 0.0

    init(rideID: UUID, timestamp: Date, lat: Double, lon: Double) {
        self.rideID = rideID
        self.timestamp = timestamp
        self.lat = lat
        self.lon = lon
    }
}

/// A dwell of 120s or more inside a ride (decision 29). Raw and unclassified until v1.5
/// tunes toll / signal / fuel detection on real routes (decision 30).
@Model
final class StopEvent: SyncRecord {
    var id = UUID()
    var ownerID = UUID.unowned
    var createdAt = Date.now
    var updatedAt = Date.now
    var deletedAt: Date?
    var syncScope = SyncScope.syncable

    var rideID = UUID.unowned
    var startedAt = Date.now
    var endedAt = Date.now
    var lat = 0.0
    var lon = 0.0

    init(rideID: UUID, startedAt: Date, endedAt: Date, lat: Double, lon: Double) {
        self.rideID = rideID
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.lat = lat
        self.lon = lon
    }
}
