# Architecture

SwiftUI + SwiftData, iOS 18+, iPhone 16 target. No backend in v1.

## Layers
```
Views (SwiftUI)
  └── @Observable Services        RideRecorder, CaptureService, ServiceScheduler,
                                  DocumentReminder, SummaryBuilder, LocationService
        └── Repositories          protocol-backed, every query scoped by CurrentUser
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
- Accuracy tiering: 1 Hz full accuracy while Ride mode is foregrounded, reduced
  cadence when backgrounded. GPS is the dominant battery cost — far more than screen.
- `CMAltimeter` for barometric climb (more accurate than GPS altitude).
- Autosave every 15s so a crash or kill never loses more than a few seconds.

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
