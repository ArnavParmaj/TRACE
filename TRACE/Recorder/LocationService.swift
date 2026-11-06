import CoreLocation
import CoreMotion

/// Where fixes and altitude come from. Live hardware in the app, a stub in tests.
@MainActor
protocol RideSensors: AnyObject {
    func start(onFix: @escaping @MainActor @Sendable (Fix) -> Void,
               onAltitude: @escaping @MainActor @Sendable (Double) -> Void)
    func stop()
}

/// GPS at 1 Hz, best accuracy, never auto-paused, plus the barometer for climb.
/// Background recording needs only the `location` background mode: no paid entitlement.
@MainActor
final class LocationService: NSObject, RideSensors, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private let altimeter = CMAltimeter()
    private var onFix: (@MainActor @Sendable (Fix) -> Void)?
    private var startedAt = Date.distantPast
    private var lastFix: Fix?

    /// The rider said no (or a profile blocks it): a ride would record nothing.
    static var isDenied: Bool { [.denied, .restricted].contains(CLLocationManager().authorizationStatus) }

    override init() {
        super.init()
        manager.delegate = self
        manager.activityType = .otherNavigation
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = kCLDistanceFilterNone
        // Auto-pause would stop updates at a signal and lose the stop and auto-close timing.
        manager.pausesLocationUpdatesAutomatically = false
        manager.showsBackgroundLocationIndicator = true
    }

    func start(onFix: @escaping @MainActor @Sendable (Fix) -> Void,
               onAltitude: @escaping @MainActor @Sendable (Double) -> Void) {
        self.onFix = onFix
        startedAt = .now
        lastFix = nil
        // When-in-use is enough: updates started in the foreground continue in the background.
        manager.requestWhenInUseAuthorization()
        manager.allowsBackgroundLocationUpdates = true
        manager.startUpdatingLocation()

        guard CMAltimeter.isRelativeAltitudeAvailable() else { return }   // simulator: no barometer
        altimeter.startRelativeAltitudeUpdates(to: .main) { data, _ in
            guard let metres = data?.relativeAltitude.doubleValue else { return }
            MainActor.assumeIsolated { onAltitude(metres) }
        }
    }

    func stop() {
        manager.stopUpdatingLocation()
        manager.allowsBackgroundLocationUpdates = false
        altimeter.stopRelativeAltitudeUpdates()
        onFix = nil
    }

    // The manager was created on the main thread, so CoreLocation calls back on it.
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        MainActor.assumeIsolated {
            let warm = Date.now.timeIntervalSince(startedAt) > RideStats.coldStartS
            for location in locations {
                var fix = Fix(location, warmedUp: warm)
                if fix.speedMps < 0, warm, let prev = lastFix, let mps = fix.derivedSpeed(from: prev) {
                    fix.speedMps = mps
                }
                lastFix = fix
                onFix?(fix)
            }
        }
    }
}

extension Fix {
    init(_ location: CLLocation, warmedUp: Bool = false) {
        // Cold-start fixes carry a bogus speed (17 km/h standing). Mark it invalid (-1, CoreLocation's
        // own convention) so the gauge, stats and analysis all skip it; the position is still stored.
        let limit = warmedUp ? RideStats.warmSpeedAccuracyMps : RideStats.maxSpeedAccuracyMps
        let trusted = location.horizontalAccuracy >= 0 && location.horizontalAccuracy <= RideStats.maxAccuracyM
            && (location.speedAccuracy < 0 || location.speedAccuracy <= limit)
        self.init(time: location.timestamp,
                  lat: location.coordinate.latitude, lon: location.coordinate.longitude,
                  altitudeM: location.altitude, speedMps: trusted ? location.speed : -1,
                  accuracyM: location.horizontalAccuracy)
    }

    /// Speed from the last good position when the reported one is invalid. Nil when the step is
    /// too short to beat the position error (standing-still jitter) or the fixes are too far apart.
    func derivedSpeed(from prev: Fix) -> Double? {
        let dt = time.timeIntervalSince(prev.time)
        guard dt > 0, dt <= 3, accuracyM >= 0, accuracyM <= RideStats.maxAccuracyM else { return nil }
        let d = CLLocation(latitude: prev.lat, longitude: prev.lon)
            .distance(from: CLLocation(latitude: lat, longitude: lon))
        let mps = d / dt
        return d > max(accuracyM, prev.accuracyM) && mps >= RideStats.stillBelowMps ? mps : nil
    }
}
