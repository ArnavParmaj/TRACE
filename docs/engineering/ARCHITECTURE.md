# Architecture

SwiftUI + SwiftData, iOS 18+, iPhone 16 target. No backend in v1.

## Layers
```
Views (SwiftUI)
  └── @Observable Services        RideRecorder, CaptureService, ServiceScheduler,
                                  DocumentReminder, SummaryBuilder, LocationService
        └── Repository<T>         one generic type, every query scoped by CurrentUser
                                  (tests use an in-memory container, no mocks: decision 42)
              └── SwiftData models
```
`CurrentUser` is a protocol with a single local stub implementation in v1. Every
repository method takes its `ownerID` from it. v2 swaps the implementation; no
call site changes. This is the whole multi-tenant preparation — an afternoon now.

## Capture path (the product's spine)
1. **Action Button** → App Intent → writes a `CaptureDraft` → returns immediately.
   The intent never blocks on UI. The tap must always succeed, even mid-corner.
2. **Control Center control** → same App Intent.
3. **Live Activity** → shows the running ride; tap to log.
4. Drafts surface on Today for completion when stopped.

## Ride recording
- `CLLocationManager`, `allowsBackgroundLocationUpdates = true`,
  `activityType = .otherNavigation`, background mode declared in Info.plist.
  This needs **no paid entitlement**.
- 1 Hz, best accuracy, `pausesLocationUpdatesAutomatically = false`, in foreground
  and background alike. Accuracy tiering is deferred until the M2 ride measures the
  drain (decision 45). GPS is the dominant battery cost — far more than screen.
- When-in-use authorization is enough: updates started in the foreground keep running
  in the background (blue location pill).
- `CMAltimeter` for barometric climb (more accurate than GPS altitude). Rises under 2 m
  are treated as noise. The simulator has no barometer, so climb reads 0 there.
- Autosave every 15s, timed off fix timestamps rather than a timer so it runs in the
  background, plus a save whenever the app is backgrounded (decision 47).
- Code: `TRACE/Recorder/` — `RideStats` (pure maths, unit-tested), `LocationService`
  (CoreLocation + barometer behind the `RideSensors` protocol), `RideRecorder`
  (start / pause / resume / stop / autosave / auto-close / recovery).
- Pause turns GPS and the barometer off; the ride stays open (decision 51).
- Closing a ride runs the fusion rule (`Ledger.fuse`) and sets `lastClosed`, which Today
  turns into the one-time recap (S05).

## Code map
| Folder | What lives there |
|---|---|
| `TRACE/Models/` | SwiftData models: route, money (local-only), bike ops, `SyncRecord` |
| `TRACE/Data/` | `Store` (synced + local-only containers), `Repository<T>` (owner-scoped, soft delete), `CurrentUser` |
| `TRACE/Recorder/` | GPS + barometer recording, autosave, recovery |
| `TRACE/Capture/` | `Capture` (draft queue) and `LogEntryIntent` (Action Button) |
| `TRACE/Money/` | `Ledger`: expenses, fusion, attach / detach, km/L (decision 64) |
| `TRACE/Bike/` | `Garage`, computed `Due` state, `Reminders` (local notifications) |
| `TRACE/Design/` | `Tokens` (from DESIGN.md, Display P3), `Hatch`, `ScreenHeader` |
| `TRACE/Support/` | `Money` formatting: paise ↔ text, view layer only |
| `TRACE/App/` | Views. Dumb: they call services, never fetch models directly |

## Notifications
`UNUserNotificationCenter`, local only — service due and document expiry. Local
notifications need **no push entitlement**, so they work on free signing.

## RESOLVED — App Groups on free signing (decision 39, 2026-10-21)
Spiked on the iPhone 16 with the free Personal Team: a widget extension and the app both
signed with `group.com.arnavparmaj.trace`, and the app got a real shared container at
runtime. Extensions can share the store. The original risk note is kept below for history.

~~Free provisioning does not grant App Groups.~~ (Disproved.) A WidgetKit or Control Center extension
that reads the SwiftData store directly needs a shared container, which may therefore
be unavailable until the $99 account exists.

**Spike this first.** Mitigation if it is blocked: controls and intents that only
*launch an App Intent in the main app* avoid the shared container entirely; the
Action Button path survives regardless. Live Activity content is passed as ActivityKit
state rather than read from the store, so it should also survive. Do not architect
around the widget until the spike answers this — and do not let it block v1, because
the Action Button is the primary capture path anyway.

## What free signing costs, in full
- Re-sign from Xcode every 7 days (app data survives re-deploy)
- Max 3 sideloaded apps
- No push, no iCloud/CloudKit, no HomeKit (App Groups do work: decision 39)
- Cannot install on anyone else's device in any sustainable way

## Build order
1. Models + repositories + CurrentUser stub
2. Ride recording and persistence (the hardest part — do it first, not last)
3. Today screen (artboard E)
4. Capture: App Intent + Action Button
5. Expenses + the fusion rule
6. Service tasks and due computation
7. Documents and expiry notifications
8. Ride mode screen (artboard F)
9. Map replay + Swift Charts trends
10. Weekly and per-trip summaries

Recording first because everything else is CRUD, and CRUD never surprises you.
