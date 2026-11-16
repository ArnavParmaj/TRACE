import SwiftData
import WidgetKit

/// Builds the widget's snapshot from the store and reloads the widget when it changed (decision 91).
/// Called when the app leaves the foreground, when a ride starts, pauses or stops, and after a draft.
@MainActor
enum WidgetFeed {
    static let minRideM = 500

    /// `recorder` nil (the capture intent, which has none): the ride part is kept as it was.
    static func refresh(context: ModelContext, recorder: RideRecorder?, logged: Bool = false, now: Date = .now) {
        let user = LocalStubUser.load()
        let old = WidgetSnapshot.load()
        var new = WidgetSnapshot(soonShare: Preferences.soonShare)

        let garage = Garage(context: context, user: user)
        if let bike = try? garage.bike() {
            new.hasBike = true
            new.odometerKm = bike.odometerKm
            new.tasks = ((try? garage.tasks(bike, now: now)) ?? []).map {
                .init(id: $0.id, label: $0.label, lastDoneOdoKm: $0.lastDoneOdoKm, lastDoneAt: $0.lastDoneAt,
                      intervalKm: $0.intervalKm, intervalDays: $0.intervalDays, snoozedUntil: $0.snoozedUntil)
            }
            new.docs = ((try? garage.documents(bike)) ?? []).map { .init(id: $0.id, label: $0.kind.label, expiresOn: $0.expiresOn) }
        }
        new.drafts = (try? Capture(context: context, user: user).pending().count) ?? 0

        // A ride that covered no ground is not a ride to the widget: a parked test read 8 m.
        let rides = ((try? Repository<Ride>(context: context, user: user).finished()) ?? [])
            .filter { $0.distanceM >= minRideM && $0.endedAt != nil }
        let weekAgo = now.addingTimeInterval(-8 * 86_400)
        new.rides = rides.enumerated().filter { $0.offset == 0 || $0.element.endedAt! > weekAgo }.map { lite($0.element) }
        // The first ride ever holds every record; that is not news.
        if rides.count > 1, let last = rides.first, let record = Review.bests(rides).records(for: last).first {
            new.best = best(record, last)
        }

        if let recorder {
            new.live = recorder.ride.map {
                .init(startedAt: $0.startedAt, clockStart: $0.startedAt.addingTimeInterval(Double($0.pausedDurationS)),
                      pausedS: $0.pausedAt == nil ? nil : Int(recorder.elapsed(at: now)))
            }
        } else {
            new.live = old.live
        }

        new.loggedAt = logged ? now : old.loggedAt

        guard new != old else { return }
        new.save()
        WidgetCenter.shared.reloadAllTimelines()
    }

    private static func lite(_ ride: Ride) -> WidgetSnapshot.RideLite {
        .init(id: ride.id, endedAt: ride.endedAt ?? ride.startedAt, km: Double(ride.distanceM) / 1000,
              minutes: ride.movingDurationS / 60, topKph: Int(ride.maxSpeedKph.rounded()))
    }

    private static func best(_ record: String, _ ride: Ride) -> WidgetSnapshot.Best {
        let at = ride.endedAt ?? ride.startedAt
        switch record {
        case "TOP SPEED": return .init(title: "TOP SPEED", value: "\(Int(ride.maxSpeedKph.rounded()))", unit: "KM/H", at: at, rideID: ride.id)
        case "CLIMB": return .init(title: "BIGGEST CLIMB", value: "\(ride.climbM)", unit: "M", at: at, rideID: ride.id)
        case "10 KM":
            let s = ride.fastest10kS ?? 0
            return .init(title: "FASTEST 10 KM", value: String(format: "%d:%02d", s / 60, s % 60), unit: "MIN", at: at, rideID: ride.id)
        default: return .init(title: "LONGEST RIDE", value: "\(Int((Double(ride.distanceM) / 1000).rounded()))", unit: "KM", at: at, rideID: ride.id)
        }
    }
}
