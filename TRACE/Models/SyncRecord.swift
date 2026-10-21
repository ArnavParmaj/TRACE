import Foundation
import SwiftData

/// Whether a record may ever leave the device. Money is `.localOnly`, permanently.
enum SyncScope: String, Codable, Sendable {
    case syncable
    case localOnly
}

/// The five universal fields every model carries (DATA-MODEL.md), plus `syncScope`.
/// No `.unique` on `id`: CloudKit-backed stores reject unique constraints (decision 40).
protocol SyncRecord: PersistentModel {
    var id: UUID { get set }
    var ownerID: UUID { get set }
    var createdAt: Date { get set }
    var updatedAt: Date { get set }
    var deletedAt: Date? { get set }
    var syncScope: SyncScope { get }
}

extension UUID {
    /// Placeholder owner until a repository stamps the real one on insert.
    static let unowned = UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0))
}
