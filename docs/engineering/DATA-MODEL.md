# Data model

SwiftData. Every rule here exists so the v2 sync layer can be added without a rewrite.

## Universal fields — on EVERY model, no exceptions
```swift
@Attribute(.unique) var id: UUID        // never an autoincrement Int
var ownerID: UUID                       // the CurrentUser stub in v1
var createdAt: Date
var updatedAt: Date
var deletedAt: Date?                    // soft delete; sync needs tombstones
var syncScope: SyncScope                // .syncable or .localOnly
```
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
`isRecording: Bool`, `vehicleID: UUID`

### RouteSample   (syncable, child of Ride)
`rideID`, `timestamp`, `lat`, `lon`, `altitudeM`, `speedMps`, `horizontalAccuracyM`
Full-resolution samples for elevation profiles and future segment matching.
Downsample to the Ride's `encodedPolyline` on save; keep raw samples but allow a
retention policy later (they are the only thing that grows unboundedly).

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
