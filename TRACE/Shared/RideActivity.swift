import ActivityKit
import Foundation

/// S18: what the lock screen and Dynamic Island show for a running ride.
struct RideActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        /// Ride start pushed later by time spent paused, so a running timer shows elapsed.
        var clockStart: Date
        /// Frozen elapsed seconds while paused; nil while riding.
        var pausedAt: Int?
        var km: Double
        /// Drafts logged on this ride: the LOG button's confirmation.
        var drafts: Int
    }
}
