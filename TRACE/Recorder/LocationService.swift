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
        let fixes = locations.map(Fix.init)
        MainActor.assumeIsolated {
            for fix in fixes { onFix?(fix) }
        }
    }
}

extension Fix {
    init(_ location: CLLocation) {
        // Cold-start fixes carry a bogus speed (17 km/h standing). Mark it invalid (-1, CoreLocation's
        // own convention) so the gauge, stats and analysis all skip it; the position is still stored.
        let trusted = location.horizontalAccuracy >= 0 && location.horizontalAccuracy <= RideStats.maxAccuracyM
            && (location.speedAccuracy < 0 || location.speedAccuracy <= RideStats.maxSpeedAccuracyMps)
        self.init(time: location.timestamp,
                  lat: location.coordinate.latitude, lon: location.coordinate.longitude,
                  altitudeM: location.altitude, speedMps: trusted ? location.speed : -1,
                  accuracyM: location.horizontalAccuracy)
    }
}
