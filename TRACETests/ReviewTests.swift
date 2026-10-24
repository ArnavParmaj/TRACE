import Foundation
import SwiftData
import Testing
@testable import TRACE

private let t0 = Date(timeIntervalSince1970: 1_800_000_000)
private let metresPerDegreeLat = 111_195.0

/// 1 Hz fixes heading north; each leg is (seconds, km/h).
private func fixes(_ legs: [(Int, Double)], altitude: (Int) -> Double = { _ in 0 }) -> [Fix] {
    var out: [Fix] = []
    var lat = 19.0, s = 0
    for (seconds, kph) in legs {
        let mps = kph / 3.6
        for _ in 0..<seconds {
            out.append(Fix(time: t0.addingTimeInterval(Double(s)), lat: lat, lon: 72.8,
                           altitudeM: altitude(s), speedMps: mps))
            lat += mps / metresPerDegreeLat
            s += 1
        }
    }
    return out
}

@Suite struct RideAnalysisTests {
    @Test func timeInSpeedBands() {
        let a = RideAnalysis(fixes([(100, 30), (100, 60), (100, 90)]))
        #expect(a.bandSeconds.map { abs($0 - 100) <= 1 } == [true, true, true])
        #expect(a.segments.map(\.band) == [.slow, .moderate, .fast])
        #expect(abs(a.topSpeedKph - 90) < 0.01)
    }

    /// 10 km at 36 km/h (1,000 s), then 10 km at 72 km/h (500 s): the best 10 km is the fast one.
    @Test func fastestTenKilometres() throws {
        let a = RideAnalysis(fixes([(1001, 36), (501, 72)]))
        let best = try #require(a.fastest10kS)
        #expect(abs(best - 500) <= 5)   // test grid is ~0.5% off the ellipsoid
        #expect(RideAnalysis(fixes([(600, 36)])).fastest10kS == nil)   // 6 km: none
    }

    @Test func splitsScaleWithDistance() {
        let a = RideAnalysis(fixes([(1201, 36)]))   // 12 km at 10 m/s
        #expect(a.splitKm == 5)
        #expect(a.splits.map(\.fromKm) == [0, 5, 10])
        #expect(a.splits.prefix(2).allSatisfy { abs($0.seconds - 500) <= 5 })
    }

    @Test func pauseGapIsNotDistance() {
        var f = fixes([(101, 36)])
        let jump = fixes([(101, 36)]).map { var x = $0; x.time += 3600; x.lat += 0.5; return x }   // 55 km away, an hour later
        f += jump
        let a = RideAnalysis(f)
        #expect(abs(a.distanceM - 2000) < 20)
    }

    /// M7 exit: a 200 km ride at 1 Hz must analyse well inside the 2 s render budget.
    @Test func twoHundredKilometresIsFast() {
        let ride = fixes([(4000, 50), (4000, 90), (4000, 70)], altitude: { Double($0 % 600) })
        let clock = ContinuousClock()
        var a = RideAnalysis()
        let took = clock.measure { a = RideAnalysis(ride) }
        #expect(a.distanceM > 200_000)
        #expect(a.elevation.count <= RideAnalysis.elevationPoints + 1)
        #expect(took < .seconds(1))
    }
}

@MainActor
@Suite struct ReviewTests {
    @Test func personalBestsPickTheRightRides() {
        func ride(_ km: Int, _ top: Double, _ climb: Int, _ ten: Int?) -> Ride {
            let r = Ride(vehicleID: UUID())
            r.distanceM = km * 1000; r.maxSpeedKph = top; r.climbM = climb; r.fastest10kS = ten
            return r
        }
        let long = ride(120, 80, 100, 900), quick = ride(40, 110, 50, 600), hilly = ride(30, 70, 800, nil)
        let pb = Review.bests([long, quick, hilly, ride(0, 0, 0, nil)])
        #expect(pb.longest === long && pb.topSpeed === quick && pb.biggestClimb === hilly && pb.fastest10k === quick)
        #expect(pb.holders == [long.id, quick.id, hilly.id])
    }

    @Test func weeklyKmCoversTwelveWeeks() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let r = Ride(vehicleID: UUID(), startedAt: now)
        r.distanceM = 42_000
        let weeks = Review.weeklyKm([r], now: now)
        #expect(weeks.count == 12)
        #expect(weeks.last?.km == 42)
        #expect(weeks.dropLast().allSatisfy { $0.km == 0 })
    }

    @Test func closingARideStoresFastestTenK() throws {
        let container = try Store.container(inMemory: true)
        let user = RiderUser()
        let rec = RideRecorder(context: container.mainContext, user: user, sensors: StubSensors(), lookUpPlaces: false)
        rec.start(vehicleID: UUID(), at: t0)
        fixes([(1101, 36)]).forEach(rec.ingest)   // 11 km
        rec.stop()
        let ride = try #require(rec.lastClosed)
        #expect(abs((ride.fastest10kS ?? 0) - 1000) <= 10)
    }
}
