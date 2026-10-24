import CoreLocation
import Foundation

/// Everything S07 draws, computed from a ride's saved fixes. Pure, so it is unit-tested
/// and timed (M7 exit: a 200 km ride renders in under 2 s).
struct RideAnalysis: Sendable {
    /// Speed bands for the route colour and time-in-band (decisions 56, 62).
    enum Band: Int, CaseIterable, Sendable {
        case slow, moderate, fast   // < 40, 40–80, > 80 km/h
        init(kph: Double) { self = kph < 40 ? .slow : kph <= 80 ? .moderate : .fast }
        var label: String { ["<40", "40–80", ">80"][rawValue] }
    }

    struct Point: Sendable, Equatable { var lat: Double; var lon: Double }
    struct Segment: Sendable { var band: Band; var points: [Point] }
    struct Split: Sendable, Equatable { var fromKm: Int; var toKm: Double; var seconds: Int }
    struct Height: Sendable { var km: Double; var metres: Double }

    var segments: [Segment] = []
    var bandSeconds = [0, 0, 0]
    var topSpeedKph = 0.0
    var topSpeedAt: Point?
    var start: Point?
    var end: Point?
    var elevation: [Height] = []
    var splits: [Split] = []
    var splitKm = 1
    var fastest10kS: Int?
    var distanceM = 0.0

    static let maxGapS: TimeInterval = 60   // longer gaps are a pause or a kill: no distance across
    static let elevationPoints = 300

    init() {}

    init(_ fixes: [Fix]) {
        let good = fixes.filter { $0.accuracyM >= 0 && $0.accuracyM <= RideStats.maxAccuracyM }
        guard let first = good.first, let last = good.last else { return }
        start = Point(lat: first.lat, lon: first.lon)
        end = Point(lat: last.lat, lon: last.lon)

        // One pass: cumulative distance (moving fixes only, like RideStats), bands, top speed.
        var cum = [Double](repeating: 0, count: good.count)
        var lastMoving: Fix?
        for (i, f) in good.enumerated() {
            let p = Point(lat: f.lat, lon: f.lon)
            let kph = max(0, f.speedMps) * 3.6
            if i > 0 {
                let dt = f.time.timeIntervalSince(good[i - 1].time)
                if dt > 0, dt <= Self.maxGapS, f.speedMps >= RideStats.stillBelowMps {
                    bandSeconds[Band(kph: kph).rawValue] += Int(dt.rounded())
                }
                if dt > Self.maxGapS { lastMoving = nil }
            }
            if f.speedMps >= RideStats.stillBelowMps {
                if let lm = lastMoving { distanceM += Self.metres(lm, f) }
                lastMoving = f
                if kph > topSpeedKph { topSpeedKph = kph; topSpeedAt = p }
                let band = Band(kph: kph)
                if let seg = segments.last, seg.band == band {
                    segments[segments.count - 1].points.append(p)
                } else {
                    // New band starts where the last one ended, so the line has no gaps.
                    let joint = segments.last?.points.last
                    segments.append(Segment(band: band, points: (joint.map { [$0] } ?? []) + [p]))
                }
            }
            cum[i] = distanceM
        }

        fastest10kS = Self.fastest(10_000, cum: cum, fixes: good)
        splitKm = distanceM < 10_000 ? 1 : distanceM < 50_000 ? 5 : 10
        splits = Self.makeSplits(every: Double(splitKm) * 1000, cum: cum, fixes: good)
        elevation = Self.profile(cum: cum, fixes: good)
    }

    /// Shortest time to cover `metres` anywhere in the ride. Two pointers, O(n).
    static func fastest(_ metres: Double, cum: [Double], fixes: [Fix]) -> Int? {
        guard let total = cum.last, total >= metres else { return nil }
        var best: TimeInterval = .infinity
        var lo = 0
        for hi in cum.indices {
            while lo < hi, cum[hi] - cum[lo + 1] >= metres { lo += 1 }
            if cum[hi] - cum[lo] >= metres {
                best = min(best, fixes[hi].time.timeIntervalSince(fixes[lo].time))
            }
        }
        return best.isFinite ? Int(best.rounded()) : nil
    }

    static func makeSplits(every metres: Double, cum: [Double], fixes: [Fix]) -> [Split] {
        guard let total = cum.last, total > 0 else { return [] }
        var out: [Split] = []
        var mark = 0
        for i in cum.indices where cum[i] >= Double(out.count + 1) * metres || i == cum.count - 1 {
            let from = out.count
            let secs = Int(fixes[i].time.timeIntervalSince(fixes[mark].time).rounded())
            out.append(Split(fromKm: from * Int(metres / 1000), toKm: cum[i] / 1000, seconds: secs))
            mark = i
            if i == cum.count - 1 { break }
        }
        // A last split under 100 m is GPS noise at the finish, not a split.
        if out.count > 1, let tail = out.last, tail.toKm - Double(tail.fromKm) < 0.1 { out.removeLast() }
        return out
    }

    /// GPS altitude against distance, smoothed over 20 fixes and thinned to ~300 points.
    static func profile(cum: [Double], fixes: [Fix]) -> [Height] {
        guard fixes.count > 1 else { return [] }
        let window = 20
        var sum = 0.0
        var smooth: [Double] = []
        smooth.reserveCapacity(fixes.count)
        for i in fixes.indices {
            sum += fixes[i].altitudeM
            if i >= window { sum -= fixes[i - window].altitudeM }
            smooth.append(sum / Double(min(i + 1, window)))
        }
        let stride = max(1, fixes.count / elevationPoints)
        return Swift.stride(from: 0, to: fixes.count, by: stride).map { Height(km: cum[$0] / 1000, metres: smooth[$0]) }
    }

    private static func metres(_ a: Fix, _ b: Fix) -> Double {
        CLLocation(latitude: a.lat, longitude: a.lon).distance(from: CLLocation(latitude: b.lat, longitude: b.lon))
    }
}
