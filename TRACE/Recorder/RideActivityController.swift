import ActivityKit
import Foundation

/// Keeps the S18 Live Activity in step with the recorder: starts with the ride, updates on
/// distance, pause and drafts, ends with the ride. Local updates only: no push entitlement.
@MainActor
enum RideActivityController {
    static func sync(_ recorder: RideRecorder, capture: Capture) {
        guard let ride = recorder.ride else {
            Task { for activity in Activity<RideActivityAttributes>.activities { await activity.end(nil, dismissalPolicy: .immediate) } }
            return
        }
        let paused = ride.pausedAt.map { Int($0.timeIntervalSince(ride.startedAt)) - ride.pausedDurationS }
        let drafts = (try? capture.pending().filter { $0.rideID == ride.id }.count) ?? 0
        let state = RideActivityAttributes.ContentState(
            clockStart: ride.startedAt.addingTimeInterval(Double(ride.pausedDurationS)),
            pausedAt: paused, km: recorder.stats.distanceM / 1000, drafts: drafts)
        let content = ActivityContent(state: state, staleDate: nil)
        if !Activity<RideActivityAttributes>.activities.isEmpty {
            // Looked up inside the task: an Activity can't cross into it.
            Task { await Activity<RideActivityAttributes>.activities.first?.update(content) }
        } else if ActivityAuthorizationInfo().areActivitiesEnabled {
            _ = try? Activity.request(attributes: RideActivityAttributes(), content: content)
        }
    }
}
