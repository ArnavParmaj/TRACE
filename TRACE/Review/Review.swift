import CoreLocation
import Foundation
import SwiftData

/// Personal bests across rides (decision 62): which ride holds each.
struct PersonalBests: Equatable {
    var longest: Ride?
    var topSpeed: Ride?
    var biggestClimb: Ride?
    var fastest10k: Ride?

    /// Rides holding at least one best, for the PB badge.
    var holders: Set<UUID> { Set([longest, topSpeed, biggestClimb, fastest10k].compactMap { $0?.id }) }
}

/// Reads for the Rides tab and ride detail (S06, S07), and the derived fields a ride
/// gets after it closes: fastest 10 km and place names.
@MainActor
struct Review {
    private let rides: Repository<Ride>
    private let samples: Repository<RouteSample>
    private let stops: Repository<StopEvent>

    init(context: ModelContext, user: any CurrentUser) {
        rides = Repository(context: context, user: user)
        samples = Repository(context: context, user: user)
        stops = Repository(context: context, user: user)
    }

    func analysis(of ride: Ride) throws -> RideAnalysis {
        RideAnalysis(try samples.samples(of: ride.id).map(Fix.init))
    }

    func stops(of ride: Ride) throws -> [StopEvent] { try stops.stops(of: ride.id) }

    /// Rides that never got a fastest 10 km, though long enough for one.
    func fillFastest(_ list: [Ride]) throws {
        let missing = list.filter { $0.fastest10kS == nil && $0.distanceM >= 10_000 && !$0.isRecording }
        guard !missing.isEmpty else { return }
        for ride in missing {
            let value = try analysis(of: ride).fastest10kS
            rides.update(ride) { $0.fastest10kS = value }
        }
        try rides.save()
    }

    /// Start and end place names from the first and last fix. Needs the network, so it
    /// is retried whenever the Rides tab opens; offline it simply leaves them nil.
    func fillPlaces(_ list: [Ride], limit: Int = 4) async {
        let missing = list.filter { $0.startPlaceName == nil && !$0.isRecording && $0.distanceM > 0 }.prefix(limit)
        for ride in missing {
            guard let first = try? samples.endSample(of: ride.id, last: false),
                  let last = try? samples.endSample(of: ride.id, last: true) else { continue }
            guard let from = await Self.place(first.lat, first.lon) else { return }   // offline: stop trying
            let to = await Self.place(last.lat, last.lon)
            rides.update(ride) {
                $0.startPlaceName = from
                $0.endPlaceName = to
            }
            try? rides.save()
        }
    }

    /// Neighbourhood or town name, e.g. "Bandra West" or "Lonavala".
    static func place(_ lat: Double, _ lon: Double) async -> String? {
        let marks = try? await CLGeocoder().reverseGeocodeLocation(CLLocation(latitude: lat, longitude: lon))
        guard let m = marks?.first else { return nil }
        return m.subLocality ?? m.locality ?? m.name
    }

    static func bests(_ list: [Ride]) -> PersonalBests {
        let real = list.filter { $0.distanceM > 0 }
        return PersonalBests(
            longest: real.max { $0.distanceM < $1.distanceM },
            topSpeed: real.max { $0.maxSpeedKph < $1.maxSpeedKph },
            biggestClimb: real.filter { $0.climbM > 0 }.max { $0.climbM < $1.climbM },
            fastest10k: real.filter { $0.fastest10kS != nil }.min { $0.fastest10kS! < $1.fastest10kS! })
    }

    /// Kilometres per ISO week, oldest first, the last `weeks` weeks ending this week.
    static func weeklyKm(_ list: [Ride], weeks: Int = 12, now: Date = .now) -> [(week: Date, km: Double)] {
        let cal = Calendar(identifier: .iso8601)
        guard let thisWeek = cal.dateInterval(of: .weekOfYear, for: now)?.start else { return [] }
        let starts = (0..<weeks).reversed().compactMap { cal.date(byAdding: .weekOfYear, value: -$0, to: thisWeek) }
        var km = [Date: Double]()
        for r in list {
            if let w = cal.dateInterval(of: .weekOfYear, for: r.startedAt)?.start { km[w, default: 0] += Double(r.distanceM) / 1000 }
        }
        return starts.map { ($0, km[$0] ?? 0) }
    }
}
