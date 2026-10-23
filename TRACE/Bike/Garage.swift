import Foundation
import SwiftData

enum Trip { case a, b }

/// Bike ops data: the bike, odometer, trip meters, service tasks and documents.
@MainActor
struct Garage {
    enum Failure: Error { case odometerWentDown }

    private let vehicles: Repository<Vehicle>
    private let rides: Repository<Ride>
    private let tasks: Repository<ServiceTask>
    private let events: Repository<ServiceEvent>
    private let docs: Repository<VehicleDocument>
    private let expenses: Repository<Expense>

    init(context: ModelContext, user: any CurrentUser) {
        vehicles = Repository(context: context, user: user)
        rides = Repository(context: context, user: user)
        tasks = Repository(context: context, user: user)
        events = Repository(context: context, user: user)
        docs = Repository(context: context, user: user)
        expenses = Repository(context: context, user: user)
    }

    // MARK: Bike + odometer

    /// The bike shown everywhere. One bike in v1 (decision 28).
    func bike() throws -> Vehicle? {
        let all = try vehicles.all(sortBy: [SortDescriptor(\.createdAt)])
        return all.first(where: \.isPrimary) ?? all.first
    }

    @discardableResult
    func addBike(name: String, registration: String?, odometerKm: Int, at time: Date = .now) throws -> Vehicle {
        let bike = Vehicle(name: name, odometerKm: odometerKm)
        bike.registrationNumber = registration
        bike.odometerUpdatedAt = time
        bike.isPrimary = true
        vehicles.insert(bike)
        try vehicles.save()
        return bike
    }

    func updateBike(_ bike: Vehicle, name: String, registration: String?) throws {
        vehicles.update(bike) { $0.name = name; $0.registrationNumber = registration }
        try vehicles.save()
    }

    /// Soft: rides keep their vehicle ID, and its tasks and documents stop showing.
    func removeBike(_ bike: Vehicle) throws {
        vehicles.softDelete(bike)
        try vehicles.save()
    }

    /// Manual and authoritative (decision 24). A lower reading needs `allowLower`
    /// ("odometer replaced?", S14).
    func setOdometer(_ bike: Vehicle, km: Int, allowLower: Bool = false, at time: Date = .now) throws {
        guard km >= bike.odometerKm || allowLower else { throw Failure.odometerWentDown }
        vehicles.update(bike) { $0.odometerKm = km; $0.odometerUpdatedAt = time }
        try vehicles.save()
    }

    /// Last reading plus recorded rides since it. A hint only; GPS drifts 2–5%.
    func odometerSuggestion(_ bike: Vehicle) throws -> Int {
        bike.odometerKm + Int(try kmRidden(bike, since: bike.odometerUpdatedAt ?? bike.createdAt).rounded())
    }

    func tripKm(_ bike: Vehicle, _ trip: Trip) throws -> Double {
        try kmRidden(bike, since: (trip == .a ? bike.tripAResetAt : bike.tripBResetAt) ?? .distantPast)
    }

    func resetTrip(_ bike: Vehicle, _ trip: Trip, at time: Date = .now) throws {
        vehicles.update(bike) { if trip == .a { $0.tripAResetAt = time } else { $0.tripBResetAt = time } }
        try vehicles.save()
    }

    private func kmRidden(_ bike: Vehicle, since: Date) throws -> Double {
        let metres = try rides.finished().filter { $0.vehicleID == bike.id && $0.startedAt >= since }.map(\.distanceM).reduce(0, +)
        return Double(metres) / 1000
    }

    // MARK: Service

    /// Active tasks, most urgent first.
    func tasks(_ bike: Vehicle, now: Date = .now) throws -> [ServiceTask] {
        try tasks.all(sortBy: [SortDescriptor(\.createdAt)])
            .filter { $0.vehicleID == bike.id && $0.isActive }
            .sorted { due($0, bike, now: now).urgency < due($1, bike, now: now).urgency }
    }

    func due(_ task: ServiceTask, _ bike: Vehicle, now: Date = .now) -> DueStatus {
        Due.service(lastDoneOdoKm: task.lastDoneOdoKm, lastDoneAt: task.lastDoneAt, intervalKm: task.intervalKm,
                    intervalDays: task.intervalDays, odometerKm: bike.odometerKm, now: now)
    }

    func save(_ task: ServiceTask, for bike: Vehicle) throws {
        if task.ownerID == .unowned { task.vehicleID = bike.id; tasks.insert(task) } else { tasks.update(task) { _ in } }
        try tasks.save()
    }

    /// Soft: history stays (invariant 5).
    func remove(_ task: ServiceTask) throws {
        tasks.softDelete(task)
        try tasks.save()
    }

    /// Logs the service, resets the task's interval, raises the odometer if this reading is
    /// newer, and keeps any cost in a local-only expense (decision 60).
    @discardableResult
    func markDone(_ task: ServiceTask, bike: Vehicle, odometerKm: Int, costMinor: Int? = nil,
                  notes: String? = nil, at time: Date = .now) throws -> ServiceEvent {
        let event = ServiceEvent(vehicleID: bike.id, odometerKm: odometerKm, performedAt: time)
        event.taskID = task.id
        event.notes = notes
        events.insert(event)
        tasks.update(task) { $0.lastDoneOdoKm = odometerKm; $0.lastDoneAt = time }
        if odometerKm > bike.odometerKm {
            vehicles.update(bike) { $0.odometerKm = odometerKm; $0.odometerUpdatedAt = time }
        }
        if let costMinor, costMinor > 0 {
            let expense = Expense(amountMinor: costMinor, category: .parts, occurredAt: time)
            expense.vehicleID = bike.id
            expense.serviceEventID = event.id
            expense.odometerKm = odometerKm
            expense.note = task.label
            expenses.insert(expense)
        }
        try events.save()
        return event
    }

    /// Past services, newest first, each with its cost if one was paid.
    func history(_ task: ServiceTask) throws -> [(event: ServiceEvent, costMinor: Int?)] {
        let costs = Dictionary(try expenses.all().compactMap { e in e.serviceEventID.map { ($0, e.amountMinor) } },
                               uniquingKeysWith: +)
        return try events.all(sortBy: [SortDescriptor(\.performedAt, order: .reverse)])
            .filter { $0.taskID == task.id }
            .map { ($0, costs[$0.id]) }
    }

    // MARK: Documents

    /// This bike's documents plus ones tied to no bike (a licence), soonest expiry first.
    func documents(_ bike: Vehicle) throws -> [VehicleDocument] {
        try docs.all(sortBy: [SortDescriptor(\.expiresOn)]).filter { $0.vehicleID == nil || $0.vehicleID == bike.id }
    }

    func save(_ doc: VehicleDocument) throws {
        if doc.ownerID == .unowned { docs.insert(doc) } else { docs.update(doc) { _ in } }
        try docs.save()
    }

    func remove(_ doc: VehicleDocument) throws {
        docs.softDelete(doc)
        try docs.save()
    }

    // MARK: Today's 03 DUE

    /// Overdue and due-soon tasks and documents, most urgent first.
    func dueItems(now: Date = .now) throws -> [(label: String, status: DueStatus)] {
        guard let bike = try bike() else { return [] }
        let service = try tasks(bike, now: now).map { (label: $0.label, status: due($0, bike, now: now)) }
        let papers = try documents(bike).map { (label: $0.kind.label, status: Due.document(expiresOn: $0.expiresOn, now: now)) }
        return (service + papers).filter { $0.status.urgency <= .soon }.sorted { $0.status.urgency < $1.status.urgency }
    }
}
