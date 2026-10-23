import CoreLocation
import Foundation

/// One GPS fix. Plain value so the ride maths is testable without CoreLocation running.
struct Fix: Sendable {
    var time: Date
    var lat: Double
    var lon: Double
    var altitudeM = 0.0
    var speedMps = 0.0
    var accuracyM = 5.0
}

/// A finished dwell of 120s or more (decision 29). Raw, unclassified (decision 30).
struct StopSpan: Equatable {
    var start: Date
    var end: Date
    var lat: Double
    var lon: Double
}

/// Ride maths: distance, stopped time, stops, climb and the route points for the polyline.
struct RideStats {
    static let stillBelowMps = 1.0                      // ~3.6 km/h counts as standing still
    static let stopAfterS: TimeInterval = 120           // decision 29
    static let autoCloseAfterS: TimeInterval = 1800     // decision 50 (was 10 min, decision 23)
    static let stillRadiusM = 50.0                      // moving further than this restarts the still clock
    static let maxAccuracyM = 30.0                      // worse fixes are stored but not counted
    static let climbStepM = 2.0                         // barometer noise floor

    private(set) var distanceM = 0.0
    private(set) var stoppedS = 0.0
    private(set) var maxSpeedMps = 0.0
    private(set) var climbM: Double
    private(set) var points: [Coordinate] = []
    /// First fix of the current still spell, if the bike is standing.
    private(set) var stillSince: Fix?
    private var lastMoving: Fix?
    private var altitudeAnchor: Double?

    struct Coordinate: Equatable { var lat: Double; var lon: Double }

    init(climbM: Double = 0) { self.climbM = climbM }

    /// Feeds one fix. Returns a stop when movement resumes after a long enough dwell.
    mutating func add(_ fix: Fix) -> StopSpan? {
        guard fix.accuracyM >= 0, fix.accuracyM <= Self.maxAccuracyM, fix.speedMps >= 0 else { return nil }

        if fix.speedMps < Self.stillBelowMps {
            // Creeping through gridlock reads as low speed but covers ground: past 50 m from
            // where the spell began, it is not one still spell. Distance is still counted at
            // the next moving fix, which measures from the last moving point.
            if let still = stillSince, Self.metres(still, fix) <= Self.stillRadiusM { return nil }
            stillSince = fix
            return nil   // standing still: GPS jitter is not distance
        }

        maxSpeedMps = max(maxSpeedMps, fix.speedMps)
        if let last = lastMoving { distanceM += Self.metres(last, fix) }
        lastMoving = fix
        points.append(Coordinate(lat: fix.lat, lon: fix.lon))

        guard let still = stillSince else { return nil }
        stillSince = nil
        let dwell = fix.time.timeIntervalSince(still.time)
        guard dwell >= Self.stopAfterS else { return nil }   // short stops are moving time
        stoppedS += dwell
        return StopSpan(start: still.time, end: fix.time, lat: still.lat, lon: still.lon)
    }

    /// After a pause: the next fix starts a new track segment, so distance is not
    /// bridged across wherever the bike went while GPS was off.
    mutating func breakTrack() {
        lastMoving = nil
        stillSince = nil
    }

    /// True once the bike has stood within 50 m for 30 minutes: the forgotten-stop fallback.
    func shouldAutoClose(at time: Date) -> Bool {
        guard let still = stillSince else { return false }
        return time.timeIntervalSince(still.time) >= Self.autoCloseAfterS
    }

    /// Barometric relative altitude. Counts rises of at least `climbStepM` from the lowest
    /// point since the last counted rise, so sensor noise never accumulates.
    mutating func addAltitude(_ metres: Double) {
        guard let anchor = altitudeAnchor else { altitudeAnchor = metres; return }
        if metres < anchor {
            altitudeAnchor = metres
        } else if metres - anchor >= Self.climbStepM {
            climbM += metres - anchor
            altitudeAnchor = metres
        }
    }

    private static func metres(_ a: Fix, _ b: Fix) -> Double {
        CLLocation(latitude: a.lat, longitude: a.lon).distance(from: CLLocation(latitude: b.lat, longitude: b.lon))
    }
}

/// Google encoded-polyline format, 1e-5 degree precision. Readable by MapKit tooling and
/// every map library, so the replay screen needs no custom decoder format.
enum Polyline {
    static func encode(_ points: [RideStats.Coordinate]) -> String {
        var out = ""
        var prevLat = 0, prevLon = 0
        for p in points {
            let lat = Int((p.lat * 1e5).rounded()), lon = Int((p.lon * 1e5).rounded())
            append(lat - prevLat, to: &out)
            append(lon - prevLon, to: &out)
            prevLat = lat
            prevLon = lon
        }
        return out
    }

    private static func append(_ delta: Int, to out: inout String) {
        var v = delta < 0 ? ~(delta << 1) : delta << 1
        while v >= 0x20 {
            out.unicodeScalars.append(Unicode.Scalar(UInt8((0x20 | (v & 0x1F)) + 63)))
            v >>= 5
        }
        out.unicodeScalars.append(Unicode.Scalar(UInt8(v + 63)))
    }
}
