import Foundation
import SwiftData
import Testing
@testable import TRACE

struct RiderUser: CurrentUser { let ownerID = UUID() }

@MainActor
final class StubSensors: RideSensors {
    var running = false
    func start(onFix: @escaping @MainActor @Sendable (Fix) -> Void,
               onAltitude: @escaping @MainActor @Sendable (Double) -> Void) { running = true }
    func stop() { running = false }
}

private let t0 = Date(timeIntervalSince1970: 1_800_000_000)
private let metresPerDegreeLat = 111_195.0

/// One fix per second heading north from `startS`, at `speed` m/s (0 = standing).
private func ride(from startS: Int, seconds: Int, speed: Double, lat0: Double = 19.0) -> [Fix] {
    (0..<seconds).map { i in
        let s = Double(startS + i)
        return Fix(time: t0.addingTimeInterval(s), lat: lat0 + Double(i) * speed / metresPerDegreeLat,
                   lon: 72.8, speedMps: speed)
    }
}

@Suite struct RideStatsTests {
    @Test func steadyRideDistance() {
        var stats = RideStats()
        for f in ride(from: 0, seconds: 61, speed: 10) { _ = stats.add(f) }
        #expect(abs(stats.distanceM - 600) < 3)
        #expect(stats.maxSpeedMps == 10)
        #expect(stats.points.count == 61)
    }

    @Test func shortStopIsMovingTime() {
        var stats = RideStats()
        var spans: [StopSpan] = []
        for f in ride(from: 0, seconds: 30, speed: 10) + ride(from: 30, seconds: 60, speed: 0)
            + ride(from: 90, seconds: 30, speed: 10) {
            if let s = stats.add(f) { spans.append(s) }
        }
        #expect(spans.isEmpty)
        #expect(stats.stoppedS == 0)
    }

    @Test func longStopIsRecorded() {
        var stats = RideStats()
        var spans: [StopSpan] = []
        for f in ride(from: 0, seconds: 30, speed: 10) + ride(from: 30, seconds: 180, speed: 0)
            + ride(from: 210, seconds: 30, speed: 10) {
            if let s = stats.add(f) { spans.append(s) }
        }
        #expect(spans.count == 1)
        #expect(spans.first?.start == t0.addingTimeInterval(30))
        #expect(stats.stoppedS == 180)
    }

    @Test func standingJitterAndBadFixesAddNoDistance() {
        var stats = RideStats()
        for f in ride(from: 0, seconds: 60, speed: 0.4) { _ = stats.add(f) }     // jitter while parked
        var bad = ride(from: 60, seconds: 30, speed: 10)
        for i in bad.indices { bad[i].accuracyM = 120 }                          // tunnel / urban canyon
        for f in bad { _ = stats.add(f) }
        #expect(stats.distanceM == 0)
    }

    @Test func autoCloseAfterThirtyMinutesStill() {
        var stats = RideStats()
        for f in ride(from: 0, seconds: 10, speed: 10) + ride(from: 10, seconds: 1800, speed: 0) { _ = stats.add(f) }
        #expect(!stats.shouldAutoClose(at: t0.addingTimeInterval(1808)))
        #expect(stats.shouldAutoClose(at: t0.addingTimeInterval(1810)))
    }

    /// Mumbai gridlock: speed reads under 1 m/s for 40 minutes, but the bike creeps forward.
    /// Every 50 m of creep restarts the still clock, so the ride never auto-closes.
    @Test func gridlockCreepDoesNotAutoClose() {
        var stats = RideStats()
        let creep = ride(from: 10, seconds: 2400, speed: 0.5)   // 0.5 m/s: 1.2 km in 40 min
        for f in ride(from: 0, seconds: 10, speed: 10) + creep { _ = stats.add(f) }
        #expect(!stats.shouldAutoClose(at: creep.last!.time))
        #expect(stats.stoppedS == 0)
    }

    @Test func climbIgnoresBarometerNoise() {
        var stats = RideStats()
        for m in [0, 0.5, 0.2, 1.0, 2.5, 1.0, 3.5] { stats.addAltitude(m) }
        #expect(stats.climbM == 5.0)   // 0→2.5 and 1.0→3.5; the sub-2 m wiggles don't count
    }

    @Test func polylineMatchesReferenceEncoding() {
        // Google's published example.
        let pts = [(38.5, -120.2), (40.7, -120.95), (43.252, -126.453)].map { RideStats.Coordinate(lat: $0.0, lon: $0.1) }
        #expect(Polyline.encode(pts) == "_p~iF~ps|U_ulLnnqC_mqNvxq`@")
    }
}

@MainActor
@Suite struct RideRecorderTests {
    let container = try! Store.container(inMemory: true)
    let user = RiderUser()

    private func recorder(_ context: ModelContext? = nil, _ sensors: StubSensors = StubSensors()) -> RideRecorder {
        RideRecorder(context: context ?? container.mainContext, user: user, sensors: sensors)
    }

    @Test func startRecordStop() throws {
        let sensors = StubSensors()
        let rec = recorder(nil, sensors)
        rec.start(vehicleID: UUID(), at: t0)
        #expect(sensors.running)
        ride(from: 0, seconds: 61, speed: 10).forEach(rec.ingest)
        rec.stop()
        #expect(!sensors.running)
        #expect(!rec.isRecording)

        let saved = try #require(try Repository<Ride>(context: container.mainContext, user: user).all().first)
        #expect(!saved.isRecording)
        #expect(abs(saved.distanceM - 600) <= 3)
        #expect(saved.elapsedDurationS == 60)
        #expect(saved.endedAt == t0.addingTimeInterval(60))
        #expect(!saved.encodedPolyline.isEmpty)
        let samples = try Repository<RouteSample>(context: container.mainContext, user: user).samples(of: saved.id)
        #expect(samples.count == 61)
    }

    /// The M2 exit test in miniature: kill mid-ride, relaunch, lose at most 15 seconds.
    @Test func forceKillLosesAtMostFifteenSeconds() throws {
        let rec = recorder()
        rec.start(vehicleID: UUID(), at: t0)
        ride(from: 0, seconds: 44, speed: 10).forEach(rec.ingest)   // autosaves at 0, 15, 30
        // Killed here: nothing after the last save reaches disk. A fresh context sees only saved data.

        let relaunched = recorder(ModelContext(container))
        let orphan = try #require(relaunched.orphan)
        let kept = try Repository<RouteSample>(context: ModelContext(container), user: user).samples(of: orphan.id)
        let lostS = 43 - (kept.last.map { $0.timestamp.timeIntervalSince(t0) } ?? 0)
        #expect(lostS <= RideRecorder.autosaveEveryS)
        #expect(orphan.distanceM > 250)   // totals were saved with the samples

        relaunched.endOrphan()
        #expect(relaunched.orphan == nil)
        #expect(!orphan.isRecording)
        #expect(orphan.endedAt == kept.last?.timestamp)
    }

    @Test func resumeContinuesTheSameRide() throws {
        let rec = recorder()
        rec.start(vehicleID: UUID(), at: t0)
        ride(from: 0, seconds: 31, speed: 10).forEach(rec.ingest)

        let relaunched = recorder(ModelContext(container))
        let orphan = try #require(relaunched.orphan)
        relaunched.resume()
        #expect(relaunched.ride?.id == orphan.id)
        #expect(abs(relaunched.stats.distanceM - 300) < 3)
        ride(from: 31, seconds: 30, speed: 10, lat0: 19.0 + 310 / metresPerDegreeLat).forEach(relaunched.ingest)
        relaunched.stop()
        #expect(orphan.distanceM > 590)
    }

    @Test func autoClosesAtTheStartOfALongStill() throws {
        let rec = recorder()
        rec.start(vehicleID: UUID(), at: t0)
        (ride(from: 0, seconds: 20, speed: 10) + ride(from: 20, seconds: 1801, speed: 0)).forEach(rec.ingest)
        #expect(!rec.isRecording)
        let saved = try #require(try Repository<Ride>(context: container.mainContext, user: user).all().first)
        #expect(saved.endedAt == t0.addingTimeInterval(20))
        #expect(saved.elapsedDurationS == 20)
    }

    @Test func gridlockCreepKeepsTheRideOpen() throws {
        let rec = recorder()
        rec.start(vehicleID: UUID(), at: t0)
        (ride(from: 0, seconds: 20, speed: 10) + ride(from: 20, seconds: 2400, speed: 0.5)).forEach(rec.ingest)
        #expect(rec.isRecording)
    }

    @Test func pauseTurnsGPSOffAndIsNotMovingTime() throws {
        let sensors = StubSensors()
        let rec = recorder(nil, sensors)
        rec.start(vehicleID: UUID(), at: t0)
        ride(from: 0, seconds: 31, speed: 10).forEach(rec.ingest)          // 300 m, ends t30
        rec.pause()
        #expect(rec.phase == .paused)
        #expect(!sensors.running)
        ride(from: 31, seconds: 10, speed: 10).forEach(rec.ingest)         // stray fixes while paused
        #expect(rec.sampleCount == 31)

        rec.resumeFromPause(at: t0.addingTimeInterval(100))                // paused 70 s
        #expect(sensors.running)
        // Resumes 1.1 km away (bike moved during the pause): that gap is not ridden distance.
        ride(from: 100, seconds: 31, speed: 10, lat0: 19.01).forEach(rec.ingest)
        rec.stop()

        let saved = try #require(try Repository<Ride>(context: container.mainContext, user: user).all().first)
        #expect(abs(saved.distanceM - 600) <= 4)
        #expect(saved.pausedDurationS == 70)
        #expect(saved.elapsedDurationS == 130)
        #expect(saved.movingDurationS == 60)
        #expect(saved.pausedAt == nil)
    }

    @Test func stopWhilePausedEndsAtThePause() throws {
        let rec = recorder()
        rec.start(vehicleID: UUID(), at: t0)
        ride(from: 0, seconds: 31, speed: 10).forEach(rec.ingest)
        rec.pause()
        rec.stop()                                                         // hours later, say
        #expect(rec.phase == .idle)
        let saved = try #require(try Repository<Ride>(context: container.mainContext, user: user).all().first)
        #expect(saved.endedAt == t0.addingTimeInterval(30))
        #expect(saved.movingDurationS == 30)
    }

    @Test func killWhilePausedIsRecoverable() throws {
        let rec = recorder()
        rec.start(vehicleID: UUID(), at: t0)
        ride(from: 0, seconds: 31, speed: 10).forEach(rec.ingest)
        rec.pause()

        let sensors = StubSensors()
        let relaunched = recorder(ModelContext(container), sensors)
        let orphan = try #require(relaunched.orphan)
        #expect(orphan.pausedAt == t0.addingTimeInterval(30))              // the pause was saved
        relaunched.resume()
        #expect(relaunched.phase == .recording)
        #expect(sensors.running)
        #expect(orphan.pausedAt == nil)
    }

    @Test func endingAPausedOrphanEndsAtThePause() throws {
        let rec = recorder()
        rec.start(vehicleID: UUID(), at: t0)
        ride(from: 0, seconds: 31, speed: 10).forEach(rec.ingest)
        rec.pause()
        let relaunched = recorder(ModelContext(container))
        let orphan = try #require(relaunched.orphan)
        relaunched.endOrphan()
        #expect(orphan.endedAt == t0.addingTimeInterval(30))
    }

    @Test func finishedRidesAreNewestFirstAndSkipTheOpenOne() throws {
        let rec = recorder()
        rec.start(vehicleID: UUID(), at: t0)
        ride(from: 0, seconds: 5, speed: 10).forEach(rec.ingest)
        rec.stop()
        rec.start(vehicleID: UUID(), at: t0.addingTimeInterval(100))
        ride(from: 100, seconds: 5, speed: 10).forEach(rec.ingest)
        rec.stop()
        rec.start(vehicleID: UUID(), at: t0.addingTimeInterval(200))   // still recording
        #expect(rec.finishedRides().map(\.startedAt) == [t0.addingTimeInterval(100), t0])
    }

    @Test func noNewRideWhileAnOrphanIsPending() throws {
        recorder().start(vehicleID: UUID(), at: t0)
        let relaunched = recorder(ModelContext(container))
        relaunched.start(vehicleID: UUID())
        #expect(!relaunched.isRecording)   // resolve the orphan first
    }
}
