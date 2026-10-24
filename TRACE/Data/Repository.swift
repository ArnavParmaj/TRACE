import Foundation
import SwiftData

/// The only way to read or write a model. Every query is scoped to the current owner
/// and skips soft-deleted rows (invariants 4 and 5). Views never fetch directly.
@MainActor
struct Repository<Record: SyncRecord> {
    let context: ModelContext
    let user: any CurrentUser

    func all(sortBy: [SortDescriptor<Record>] = []) throws -> [Record] {
        let owner = user.ownerID
        let live = #Predicate<Record> { $0.ownerID == owner && $0.deletedAt == nil }
        return try context.fetch(FetchDescriptor(predicate: live, sortBy: sortBy))
    }

    func find(_ id: UUID) throws -> Record? {
        let owner = user.ownerID
        var descriptor = FetchDescriptor(predicate: #Predicate<Record> {
            $0.id == id && $0.ownerID == owner && $0.deletedAt == nil
        })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    func insert(_ record: Record) {
        let now = Date.now
        record.ownerID = user.ownerID
        record.createdAt = now
        record.updatedAt = now
        context.insert(record)
    }

    func update(_ record: Record, _ change: (Record) -> Void) {
        precondition(record.ownerID == user.ownerID, "record belongs to another owner")
        change(record)
        record.updatedAt = .now
    }

    /// Tombstone, never a hard delete: sync reconciles against `deletedAt`.
    func softDelete(_ record: Record) {
        precondition(record.ownerID == user.ownerID, "record belongs to another owner")
        record.deletedAt = .now
        record.updatedAt = .now
    }

    func save() throws {
        try context.save()
    }
}

extension Repository where Record == Ride {
    /// A ride still marked recording. On launch nothing is recording yet, so this is a
    /// ride the app was killed during (decision 25).
    func openRide() throws -> Ride? {
        let owner = user.ownerID
        var descriptor = FetchDescriptor(
            predicate: #Predicate<Ride> { $0.ownerID == owner && $0.deletedAt == nil && $0.isRecording },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)])
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    /// Closed rides, newest first.
    func finished() throws -> [Ride] {
        let owner = user.ownerID
        return try context.fetch(FetchDescriptor(
            predicate: #Predicate<Ride> { $0.ownerID == owner && $0.deletedAt == nil && !$0.isRecording },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]))
    }
}

extension Repository where Record == RouteSample {
    func samples(of rideID: UUID) throws -> [RouteSample] {
        let owner = user.ownerID
        return try context.fetch(FetchDescriptor(
            predicate: #Predicate<RouteSample> { $0.ownerID == owner && $0.deletedAt == nil && $0.rideID == rideID },
            sortBy: [SortDescriptor(\.timestamp)]))
    }
}

extension Repository where Record == RouteSample {
    /// The first or last fix of a ride without loading the rest.
    func endSample(of rideID: UUID, last: Bool) throws -> RouteSample? {
        let owner = user.ownerID
        var descriptor = FetchDescriptor(
            predicate: #Predicate<RouteSample> { $0.ownerID == owner && $0.deletedAt == nil && $0.rideID == rideID },
            sortBy: [SortDescriptor(\.timestamp, order: last ? .reverse : .forward)])
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }
}

extension Repository where Record == StopEvent {
    func stops(of rideID: UUID) throws -> [StopEvent] {
        let owner = user.ownerID
        return try context.fetch(FetchDescriptor(
            predicate: #Predicate<StopEvent> { $0.ownerID == owner && $0.deletedAt == nil && $0.rideID == rideID },
            sortBy: [SortDescriptor(\.startedAt)]))
    }
}
