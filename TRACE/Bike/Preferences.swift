import Foundation

/// The two reminder settings on S16. Kept in UserDefaults: device preferences, not records.
enum Preferences {
    private static var defaults: UserDefaults { .standard }

    /// Service turns "soon" inside this share of its interval (U4). 5–30%, default 15%.
    static var soonPercent: Int {
        get { defaults.object(forKey: "soonPercent") as? Int ?? 15 }
        set { defaults.set(min(30, max(5, newValue)), forKey: "soonPercent") }
    }
    static var soonShare: Double { Double(soonPercent) / 100 }

    /// Reminder lead days a new document starts with. Each document can change its own.
    static var documentLeads: [Int] {
        get { defaults.array(forKey: "documentLeads") as? [Int] ?? [30, 7, 1] }
        set { defaults.set(newValue.sorted(by: >), forKey: "documentLeads") }
    }
}
