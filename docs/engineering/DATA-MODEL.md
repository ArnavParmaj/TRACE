# Data model

SwiftData. Every rule here exists so the v2 sync layer can be added without a rewrite.

## Universal fields — on EVERY model, no exceptions
```swift
var id = UUID()                         // never an autoincrement Int; no .unique (decision 40)
var ownerID: UUID                       // the CurrentUser stub in v1
var createdAt: Date
var updatedAt: Date
var deletedAt: Date?                    // soft delete; sync needs tombstones
var syncScope: SyncScope                // .syncable or .localOnly
```
Every stored property has a default or is optional and nothing is `.unique`: both are
CloudKit rules, so v2 sync needs no schema migration (decision 40).

**Two stores.** Syncable models live in the `synced` store; `Expense` and `CaptureDraft`
live in the `local` store, which never gets a CloudKit database (`TRACE/Data/Store.swift`).

`StopEvent` (decision 30) was added with the recorder in M2.

`SyncScope.localOnly` is set on every money entity at the model level, so no future
sync pass can pick them up by accident. This is enforced in code, not by discipline.

## Entities

### Vehicle
`name`, `make`, `model`, `year`, `registrationNumber`, `odometerKm: Int`,
`tankCapacityL: Double?`, `isPrimary: Bool`
Odometer is the spine — service intervals and fuel economy both read from it.

### Ride   (syncable)
`startedAt`, `endedAt?`, `distanceM: Int`, `movingDurationS: Int`,
`elapsedDurationS: Int`, `climbM: Int`, `avgSpeedKph`, `maxSpeedKph`,
`startPlaceName?`, `endPlaceName?`, `odoStartKm: Int?`, `odoEndKm: Int?`,
`encodedPolyline: Data` (compressed route for map replay),
`isRecording: Bool`, `vehicleID: UUID`, `pausedAt: Date?` (set while paused),
`pausedDurationS: Int` (decision 51). Moving time = elapsed − stops − paused.

### RouteSample   (syncable, child of Ride)
`rideID`, `timestamp`, `lat`, `lon`, `altitudeM`, `speedMps`, `horizontalAccuracyM`
Full-resolution samples for elevation profiles and future segment matching.
`encodedPolyline` is Google's encoded-polyline string (UTF-8, 1e-5 degrees) of the
moving fixes, written when the ride closes (decision 46); keep raw samples but allow a
retention policy later (they are the only thing that grows unboundedly).

### StopEvent   (syncable, child of Ride)
`rideID`, `startedAt`, `endedAt`, `lat`, `lon`
A dwell of 120s or more below ~3.6 km/h (decision 29), raw and unclassified (decision 30).
Shorter stops count as moving time. A dwell is also broken when the bike drifts more
than 50 m from where it began, so gridlock creep is moving time, not a stop. A ride that
auto-closes after 30 minutes still (decision 50) ends at the start of that dwell, and the
dwell is not stored as a stop.

### Planned for M5: trip meters (decision 56)
`Vehicle.tripAResetAt: Date?`, `Vehicle.tripBResetAt: Date?`. The trip value is the sum
of `Ride.distanceM` started since the reset, computed, never stored (same reason as
invariant 6: a stored total goes stale when a ride is edited or deleted).

### Expense   (**localOnly — permanent**)
`occurredAt`, `amountMinor: Int` (paise — **never Double for money**),
`currencyCode: String`, `category: ExpenseCategory` (fuel, food, parts, parking, other;
decision 37), `note?`,
`rideID: UUID?` (set by the fusion rule below), `vehicleID: UUID?`,
`odometerKm: Int?`
Fuel-specific, nullable: `litres: Double?`, `pricePerLitreMinor: Int?`,
`isFullTank: Bool?` — full-tank entries are the only ones used for km/L.

### ServiceTask   (syncable)
`vehicleID`, `kind: ServiceKind` (chainLube, oilChange, brakePads, tyres, custom),
`label`, `intervalKm: Int?`, `intervalDays: Int?`,
`lastDoneOdoKm: Int?`, `lastDoneAt: Date?`, `isActive: Bool`
Due state is **computed, never stored** — stored due-dates go stale silently.

### ServiceEvent   (syncable)
`vehicleID`, `taskID?`, `performedAt`, `odometerKm: Int`, `costMinor: Int?`, `notes?`
If `costMinor` is set, a paired localOnly Expense is created. The event syncs; the
money does not.

### VehicleDocument   (syncable)
`vehicleID?`, `kind: DocumentKind` (insurance, puc, rc, drivingLicence, other),
`identifier?`, `issuedOn?`, `expiresOn: Date`, `reminderDaysBefore: [Int]`,
`attachmentPath?` (local file reference, never synced)

### CaptureDraft   (localOnly, ephemeral)
What a one-tap capture writes before you complete it: `kind`, `capturedAt`,
`locationSnapshot`, `rideID?`, `rawValue?`. Promoted to a real entity on completion.
This is what makes zero-friction capture possible — the tap always succeeds.

### Planned, v1.5+
`Segment`, `SegmentEffort` (local matching, no server), `GearItem`, `Modification`.
Model them when built; the universal fields already accommodate them.

## The fusion rule
When a Ride closes, every Expense whose `occurredAt` falls between the ride's
`startedAt` and `endedAt` and which has no `rideID` is attached to it. The attachment
is reversible and user-editable — automatic, not irreversible. This is the feature
no existing app has; it is also two lines of predicate, which is the point.

## Money
Integer minor units everywhere. `Double` for currency is a bug waiting for a
reconciliation that never balances. Format at the view layer only.
