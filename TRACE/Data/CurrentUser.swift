import Foundation

/// Who owns the data. v1 is a local stub; v2 swaps in a Sign in with Apple account
/// without any call site changing.
protocol CurrentUser: Sendable {
    var ownerID: UUID { get }
}

struct LocalStubUser: CurrentUser {
    let ownerID: UUID

    private static let key = "localStubOwnerID"

    /// Stable across launches: a new ID every launch would orphan all existing data.
    static func load(from defaults: UserDefaults = .standard) -> LocalStubUser {
        if let saved = defaults.string(forKey: key), let id = UUID(uuidString: saved) {
            return LocalStubUser(ownerID: id)
        }
        let id = UUID()
        defaults.set(id.uuidString, forKey: key)
        return LocalStubUser(ownerID: id)
    }
}
