import Foundation
import SwiftData

/// Two on-disk stores. In v2 only `synced` gets a CloudKit database; `local` never does,
/// which is how money stays on the device by construction, not by convention.
enum Store {
    static let syncableModels: [any PersistentModel.Type] = [
        Vehicle.self, Ride.self, RouteSample.self, StopEvent.self,
        ServiceTask.self, ServiceEvent.self, VehicleDocument.self,
    ]
    static let localOnlyModels: [any PersistentModel.Type] = [
        Expense.self, CaptureDraft.self,
    ]

    /// The one on-disk container per process, shared by the app and the capture intent.
    /// Crash rather than open a fresh empty store: silently losing the log is worse.
    @MainActor static let shared: ModelContainer = {
        do { return try container() } catch { fatalError("Store failed to open: \(error)") }
    }()

    static func container(inMemory: Bool = false) throws -> ModelContainer {
        let synced = ModelConfiguration("synced", schema: Schema(syncableModels),
                                        isStoredInMemoryOnly: inMemory, cloudKitDatabase: .none)
        let local = ModelConfiguration("local", schema: Schema(localOnlyModels),
                                       isStoredInMemoryOnly: inMemory, cloudKitDatabase: .none)
        return try ModelContainer(for: Schema(syncableModels + localOnlyModels),
                                  configurations: synced, local)
    }
}
