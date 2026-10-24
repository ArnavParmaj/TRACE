import Foundation
import Observation
import SwiftData

/// Records one ride at a time: start, stop, 15s autosave, 30-minute auto-close, and
/// recovery of a ride the app was killed during (decisions 25 and 50).
/// Autosave runs on fix timestamps, not a timer, so it keeps working in the background.
@MainActor
@Observable
final class RideRecorder {
    static let autosaveEveryS: TimeInterval = 15

    enum Phase: Equatable { case idle, recording, paused }

    /// The ride being recorded, nil when idle.
    private(set) var ride: Ride?
    /// An open ride found on launch that nothing is recording. Resume it or end it.
    private(set) var orphan: Ride?
    private(set) var stats = RideStats()
    private(set) var lastFix: Fix?
    private(set) var lastSave: Date?
    private(set) var sampleCount = 0
    private(set) var stopCount = 0
    private(set) var lastError: String?
    /// The ride that closed most recently, for the recap (S05).
    private(set) var lastClosed: Ride?

    private let rides: Repository<Ride>
    private let samples: Repository<RouteSample>
    private let stops: Repository<StopEvent>
    private let ledger: Ledger
    private let review: Review
    private let sensors: any RideSensors
    /// Off in tests: the lookup is async and would outlive a test's in-memory store.
    private let lookUpPlaces: Bool

    init(context: ModelContext, user: any CurrentUser, sensors: any RideSensors, lookUpPlaces: Bool = true) {
        rides = Repository(context: context, user: user)
        samples = Repository(context: context, user: user)
        stops = Repository(context: context, user: user)
        ledger = Ledger(context: context, user: user)
        review = Review(context: context, user: user)
        self.sensors = sensors
        self.lookUpPlaces = lookUpPlaces
        orphan = attempt { try rides.openRide() } ?? nil
    }

    var isRecording: Bool { ride != nil }
    var phase: Phase { ride == nil ? .idle : (ride?.pausedAt == nil ? .recording : .paused) }

    func start(vehicleID: UUID, odoStartKm: Int? = nil, at time: Date = .now) {
        guard ride == nil, orphan == nil else { return }
        let new = Ride(vehicleID: vehicleID, startedAt: time)
        new.odoStartKm = odoStartKm
        new.isRecording = true
        rides.insert(new)
        attempt { try rides.save() }
        begin(new, stats: RideStats(), samples: 0, stops: 0)
    }

    /// Continues the orphan into the same ride, rebuilding totals from its saved samples.
    func resume() {
        guard let open = orphan, let saved = rebuild(open) else { return }
        orphan = nil
        let stopTotal = attempt { try stops.stops(of: open.id).count } ?? 0
        begin(open, stats: saved.stats, samples: saved.count, stops: stopTotal)
        if open.pausedAt != nil {   // killed while paused: RESUME means ride on
            unpause(open, at: .now)
            startSensors()
        }
    }

    /// Closes the orphan at its last saved sample.
    func endOrphan() {
        guard let open = orphan, let saved = rebuild(open) else { return }
        orphan = nil
        close(open, stats: saved.stats, at: open.pausedAt ?? saved.last ?? open.updatedAt)
    }

    /// Stop ends the ride. Stopped while paused, it ends when the pause began.
    func stop() {
        guard let current = ride else { return }
        finish(current, at: current.pausedAt ?? lastFix?.time ?? .now)
    }

    /// GPS off, clock on hold. The ride stays open until resumed or stopped.
    func pause(at time: Date? = nil) {
        guard let current = ride, current.pausedAt == nil else { return }
        sensors.stop()
        let at = time ?? lastFix?.time ?? .now
        writeTotals(current, until: at)
        rides.update(current) { $0.pausedAt = at }
        attempt { try rides.save() }
        lastSave = at
    }

    func resumeFromPause(at time: Date = .now) {
        guard let current = ride, current.pausedAt != nil else { return }
        unpause(current, at: time)
        startSensors()
    }

    /// Called when the app leaves the foreground: a force-kill from the switcher then loses nothing.
    func saveNow() {
        guard let current = ride else { return }
        writeTotals(current, until: lastFix?.time ?? .now)
        attempt { try rides.save() }
        lastSave = lastFix?.time
    }

    /// One GPS fix. Stored raw, counted if good enough, saved every 15s.
    func ingest(_ fix: Fix) {
        guard let current = ride, current.pausedAt == nil else { return }
        let sample = RouteSample(rideID: current.id, timestamp: fix.time, lat: fix.lat, lon: fix.lon)
        sample.altitudeM = fix.altitudeM
        sample.speedMps = fix.speedMps
        sample.horizontalAccuracyM = fix.accuracyM
        samples.insert(sample)
        sampleCount += 1
        lastFix = fix

        if let span = stats.add(fix) {
            stops.insert(StopEvent(rideID: current.id, startedAt: span.start, endedAt: span.end,
                                   lat: span.lat, lon: span.lon))
            stopCount += 1
        }
        if stats.shouldAutoClose(at: fix.time), let still = stats.stillSince {
            finish(current, at: still.time)   // the ride ended when the bike stopped
            return
        }
        if fix.time.timeIntervalSince(lastSave ?? .distantPast) >= Self.autosaveEveryS {
            writeTotals(current, until: fix.time)
            attempt { try rides.save() }
            lastSave = fix.time
        }
    }

    func altitude(_ metres: Double) { stats.addAltitude(metres) }

    /// Closed rides for the Rides tab, newest first.
    func finishedRides() -> [Ride] { attempt { try rides.finished() } ?? [] }

    /// Blank clears the name back to the date.
    func rename(_ finished: Ride, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        rides.update(finished) { $0.title = trimmed.isEmpty ? nil : String(trimmed.prefix(60)) }
        attempt { try rides.save() }
    }

    /// Soft delete (invariant 5). Its samples stay but are only reachable through the ride.
    func delete(_ finished: Ride) {
        guard finished.id != ride?.id else { return }
        rides.softDelete(finished)
        attempt { try rides.save() }
        attempt { try ledger.detachAll(from: finished.id) }
    }

    // MARK: - Private

    private func begin(_ ride: Ride, stats: RideStats, samples: Int, stops: Int) {
        self.ride = ride
        self.stats = stats
        sampleCount = samples
        stopCount = stops
        lastFix = nil
        lastSave = nil
        if ride.pausedAt == nil { startSensors() }
    }

    private func startSensors() {
        sensors.start(onFix: { [weak self] in self?.ingest($0) },
                      onAltitude: { [weak self] in self?.altitude($0) })
    }

    private func unpause(_ ride: Ride, at time: Date) {
        guard let since = ride.pausedAt else { return }
        rides.update(ride) {
            $0.pausedDurationS += max(0, Int(time.timeIntervalSince(since)))
            $0.pausedAt = nil
        }
        stats.breakTrack()
        attempt { try rides.save() }
    }

    private func finish(_ ride: Ride, at end: Date) {
        sensors.stop()
        self.ride = nil
        close(ride, stats: stats, at: end)
    }

    private func close(_ ride: Ride, stats: RideStats, at end: Date) {
        self.stats = stats
        rides.update(ride) {
            $0.endedAt = end
            $0.isRecording = false
            $0.encodedPolyline = Data(Polyline.encode(stats.points).utf8)
        }
        writeTotals(ride, until: end)
        attempt { try rides.save() }
        attempt { try ledger.fuse(ride) }
        attempt { try review.fillFastest([ride]) }
        if lookUpPlaces {
            let review = review
            Task { await review.fillPlaces([ride]) }   // offline: retried when RIDES opens
        }
        lastClosed = ride
    }

    private func writeTotals(_ ride: Ride, until end: Date) {
        let elapsed = max(0, Int(end.timeIntervalSince(ride.startedAt)))
        let moving = max(0, elapsed - Int(stats.stoppedS) - ride.pausedDurationS)
        rides.update(ride) {
            $0.distanceM = Int(stats.distanceM)
            $0.elapsedDurationS = elapsed
            $0.movingDurationS = moving
            $0.climbM = Int(stats.climbM)
            $0.maxSpeedKph = stats.maxSpeedMps * 3.6
            $0.avgSpeedKph = moving > 0 ? stats.distanceM / Double(moving) * 3.6 : 0
        }
    }

    /// Replays saved samples. Stops are already stored, so the replayed ones are dropped.
    private func rebuild(_ ride: Ride) -> (stats: RideStats, count: Int, last: Date?)? {
        guard let saved = attempt({ try samples.samples(of: ride.id) }) else { return nil }
        var rebuilt = RideStats(climbM: Double(ride.climbM))
        for sample in saved { _ = rebuilt.add(Fix(sample)) }
        return (rebuilt, saved.count, saved.last?.timestamp)
    }

    /// A failed save must not crash a ride in progress; it is shown on screen instead.
    @discardableResult
    private func attempt<T>(_ work: () throws -> T) -> T? {
        do { return try work() } catch {
            lastError = "\(error)"
            return nil
        }
    }
}

extension Fix {
    init(_ sample: RouteSample) {
        self.init(time: sample.timestamp, lat: sample.lat, lon: sample.lon,
                  altitudeM: sample.altitudeM, speedMps: sample.speedMps,
                  accuracyM: sample.horizontalAccuracyM)
    }
}
