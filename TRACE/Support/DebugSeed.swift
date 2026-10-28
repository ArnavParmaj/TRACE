import Foundation
import SwiftData

/// Test data for the simulator, only when the app is launched with `-seedLongRide`.
/// Adds one 200 km ride (about 10,000 one-second samples) through the repositories, so the store stays valid.
/// Skipped when it already exists. Used to time the ride detail against the M7 exit (200 km in under 2 s).
@MainActor
enum DebugSeed {
    static let title = "TEST 200 KM"

    /// `-restoreFrom <dir>`: replace this install's store with a backed-up one, before the store opens.
    /// Every launch starts from the same data, so a seeded ride from an earlier test does not linger.
    static func restore(from dir: String) {
        let fm = FileManager.default
        guard let support = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return }
        try? fm.createDirectory(at: support, withIntermediateDirectories: true)
        for name in (try? fm.contentsOfDirectory(atPath: dir)) ?? [] {
            let dest = support.appendingPathComponent(name)
            try? fm.removeItem(at: dest)
            try? fm.copyItem(atPath: dir + "/" + name, toPath: dest.path)
        }
    }

    static func longRide(context: ModelContext, user: any CurrentUser) {
        let rides = Repository<Ride>(context: context, user: user)
        let samples = Repository<RouteSample>(context: context, user: user)
        guard let existing = try? rides.all(), !existing.contains(where: { $0.title == title }) else { return }

        let vehicle = (try? Garage(context: context, user: user).bike())?.id ?? UUID()
        let seconds = 10_000
        let start = Date.now.addingTimeInterval(-Double(seconds) - 3_600)
        let ride = Ride(vehicleID: vehicle, startedAt: start)
        rides.insert(ride)

        var lat = 19.0760, lon = 72.8777, distance = 0.0, climb = 0.0, top = 0.0, lastAlt = 20.0
        var points: [RideStats.Coordinate] = []
        for t in 0..<seconds {
            let time = Double(t)
            let speed = 20 + 10 * sin(time / 600)                 // 10 to 30 m/s, 72 km/h on average
            let heading = 0.6 + 0.4 * sin(time / 1_500)
            lat += cos(heading) * speed / 111_320
            lon += sin(heading) * speed / (111_320 * cos(lat * .pi / 180))
            distance += speed
            top = max(top, speed)
            let altitude = 20 + 40 * sin(time / 400) + 15 * sin(time / 97)   // rolling hills
            if altitude > lastAlt + 0.5 { climb += altitude - lastAlt }
            lastAlt = altitude

            let sample = RouteSample(rideID: ride.id, timestamp: start.addingTimeInterval(time), lat: lat, lon: lon)
            sample.altitudeM = altitude
            sample.speedMps = speed
            sample.horizontalAccuracyM = 5
            samples.insert(sample)
            points.append(RideStats.Coordinate(lat: lat, lon: lon))
        }

        rides.update(ride) {
            $0.title = title
            $0.endedAt = start.addingTimeInterval(Double(seconds))
            $0.distanceM = Int(distance)
            $0.movingDurationS = seconds
            $0.elapsedDurationS = seconds
            $0.climbM = Int(climb)
            $0.avgSpeedKph = distance / Double(seconds) * 3.6
            $0.maxSpeedKph = top * 3.6
            $0.encodedPolyline = Data(Polyline.encode(points).utf8)
            $0.isRecording = false
        }
        try? rides.save()
    }
}
