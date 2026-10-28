# Project context — TRACE

Orientation for anyone (human or agent) arriving cold. Read this once, then work from
the real specs. **This file is narrative, not authoritative** — where it disagrees with
`docs/product/PRD.md`, `docs/engineering/*` or `design/DESIGN.md`, those win, and this
file is the one to fix.

---

## What is being built

An offline-first iOS app for motorcyclists. It records rides, tracks money, and
watches the bike's upkeep — and it joins those three things, which nothing else does.

Three pillars:
- **Route** — GPS recording, replay, distance, climb, speed.
- **Money** — fuel, tolls, food, parts. Integer paise, never synced anywhere.
- **Bike ops** — service intervals off the odometer, document expiry (insurance, PUC,
  RC, DL) off dates.

The differentiator is **fusion**: when a ride closes, expenses logged inside its time
window attach to it automatically. "What did Lonavala cost?" becomes one object —
86.4 km, 2h 14m, 624 m climb, ₹480, 13.9 km/L. Strava knows the route. A bank app
knows the money. Nothing joins them.

The second differentiator is **capture that survives reality**: one press of the
iPhone 16 Action Button writes an entry and returns. No unlock, no form, no network.
Gloves on, at a pump, with a queue behind. If capture takes more than one press, the
product has failed its own premise.

## Who it is for

Arnav Parmaj — the owner, the sole developer, and the primary user. Computer
Engineering student in Mumbai, rides a motorcycle for both commute and weekend ghat
runs, currently hand-logs fuel in a notes app. Builds on an M4 MacBook Pro, targets
his own iPhone 16.

Secondary, at v2: 3-5 riding friends, each with their own account and their own data.

Explicitly not for: car drivers, cyclists, delivery fleets, or anyone wanting a
social feed.

## Why it looks the way it does

The design language is **OLED Splice** — the structure of an instrument cluster with
the typography and attitude of agit-print poster work, on a true-black ground.

Three constraints produced it, and they are not negotiable:
- **`#000000` ground.** OLED pixels are then genuinely off. Battery matters on a ride.
- **No large filled colour fields.** Outlines and hairlines, not slabs. A filled
  button is lit pixels; a bordered one is not.
- **Red is reserved** for overdue and expired states. The earlier favourite direction
  (pure Agit-Print) was rejected for exactly this: it spent red on decoration, leaving
  no alarm colour for an app whose whole ops pillar is deadline states.

The agit-print character survives as *unlit* structure — hairline diagonals, numbered
section chips, stencil slugs, condensed Oswald numerals.

## The constraint that shapes everything

The app ships on a **free Apple Developer account**. That means: no push, no
iCloud/CloudKit, no HomeKit, re-sign from Xcode
every 7 days, three sideloaded apps maximum, and no sustainable way to install on
anyone else's phone.

This is a feature, not only a limitation. It forces genuine offline-first design,
which is what the product wanted anyway. Everything needing a server — friend
sharing, leaderboards, sync — is deferred to v2, behind a single $99/yr unlock.

Never propose a solution requiring a paid entitlement without saying so out loud.

## Product shape, stated once

This is a **multi-tenant product launching with one user**, not a personal app with
sharing bolted on. Public release is real future scope. Therefore v1 is built
sync-ready even while fully offline: UUIDs not autoincrements, `ownerID` on every
record, timestamps, soft deletes, and a `CurrentUser` abstraction with a local stub.
That discipline costs an afternoon now and a data-layer rewrite later.

One promise is permanent and overrides convenience: **money never leaves the device.**
`Expense` is `syncScope = .localOnly`, enforced at the model layer, in v1 and in every
version after.

## Where things stand

**Latest (2026-10-29), M8 ship hardening in progress.** Read `docs/engineering/current_issues.md` first: it lists
every open and resolved issue. Simulator tests for M7 are in (`TRACEUITests/ReplayTimingTests.swift`): cold open 8.2 s
and the offline map pass; the 200 km ride detail takes about 2.2 s (map) to 3.3 s (elevation) against the 2 s exit, so
profile `RideSheet.loadReview()` (main-thread work) next. Debug launch arguments for tests only: `-seedLongRide`,
`-forceOffline`, `-restoreFrom <dir>` with `-localStubOwnerID <uuid>` (`TRACE/Support/DebugSeed.swift`).
Next session: (1) put every close button in one position on all screens (user request, not started);
(2) the 200 km open; (3) audit finding I-01 (decision 73); (4) phone checks: M3 real pump, M4 km/L by hand, M6 mount,
M7 timings and airplane replay, M8 steps 4-8. Reinstall on the phone every ~7 days, over the top, never uninstall.

Done: M0 scaffold, M0.5 App Groups spike (they work), M1 foundation: all models in two
stores (synced / local-only money), `CurrentUser` stub, generic owner-scoped
`Repository<T>`, design tokens + bundled fonts, empty 4-tab shell on true black,
12 tests green.

**M2, the recorder, is DONE (2026-10-23).** `TRACE/Recorder/`: `RideStats` (distance,
stops, climb, polyline; pure and unit-tested), `LocationService` (1 Hz GPS + barometer),
`RideRecorder` (start / pause / resume / stop / 15s autosave / 30-min auto-close / kill
recovery), a debug screen on the TODAY tab with haptics, and a plain ride list on RIDES
(stand-in; the real S06 is M7). 31 tests green. Passed on a real 78-min, 31 km ride:
force-kill recovered with ≤6 s lost, GPS 1 Hz throughout, battery 6.9%/h (decision 55).
Known: barometric climb reads high (252 m on a route spanning ~60 m), tune before M7's
elevation profile. Planned additions: speed-coloured route (M7), trip meters A/B (M5).
**M3 code is done and the Action Button works on the iPhone; the real-pump exit test is
pending.** `TRACE/Capture/`: `Capture` + `LogEntryIntent` (decisions 57–59).

**M5 code is done (2026-10-23), exit test pending.** `TRACE/Bike/`: `Due` (computed due
state), `Garage` (bike, odometer, trip meters A/B, tasks, mark done, documents),
`Reminders` (local notifications). Bike tab (S11) with add-bike, odometer sheet (S14),
task sheet + mark done (S12/S09), document sheet with attachment (S13); Today gained
03 DUE. Service cost no longer lives on the syncable `ServiceEvent` (decision 60).
51 tests green.

**M4 code is done (2026-10-24), exit test pending.** `TRACE/Money/Ledger.swift`: fusion
on ride close, attach / detach, km/L between consecutive full fills with odometer
(decision 64). One S08 editor for drafts, new and existing expenses (`ExpenseSheet`),
Money tab (S10: period total, by category, km/L chart, entries), `RideSheet` as the
recap after a ride and as ride detail from RIDES. 55 tests green.
Design-match pass (decision 65): hotter P3 amber, visible diagonals, chip section heads,
outlined primary buttons, Today 04 THIS WEEK + 05 RECENT, Money / recap / ride view per
the prototype canvas.

**M7 code is done (2026-10-24), exit test pending.** `TRACE/Review/`: ride analysis, personal
bests, place names, route map with offline fallback. RIDES is now S06 (12-week chart, PBs, month
list); a ride opens S07 (map, elevation, speed bands, stops, splits, cost, delete). Checked on a
copy of the real 31 km ride. 63 tests green. Simulator run 2026-10-29: cold open 8.2 s, offline map OK, 200 km ride detail 2.2 s map / 3.3 s elevation (over 2 s, I-02 in `docs/engineering/current_issues.md`); M4 rules covered by `LedgerTests`; M5 notification worked per the user. Climb left as is (decision 66). S15 dropped (decision 72).
**Next: on the iPhone, ride with two expenses logged during it and check both attach
with the right total, detach one; log two full fills with odometer and check km/L by
hand. Still open: M3 real-pump test, M5 notification test.**

**M6 code is done (2026-10-24), exit test pending.** `RideModeView` is S03 (gauge, tap to log,
hold to stop, pause, S04 recovery); the debug screen is gone. `TRACEWidgets` is the S18 Live
Activity with a LOG button running `LogEntryIntent` (decision 68). Signed device build passes.

**M8 in progress (2026-10-24).** All 18 screens mocked on the "TRACE v1 Screens" canvas and
approved. Done so far:
- S01 onboarding (`OnboardingView`, also the add-bike flow) and S16 settings (`SettingsView`,
  ⚙ on Today): primary-bike picker, due-soon share, document lead defaults
  (`TRACE/Bike/Preferences.swift`), storage, about (decision 67).
- File protection stays at the iOS default; route samples are kept in full and indexed by ride,
  no thinning, soft deletes only (decision 69, supersedes 27).
- Fusion also covers expenses added or re-timed after a ride closes (decision 70).
- Rides record odometer start/end from readings the rider already enters; ride detail shows
  "ODO a → b KM" (decision 71).
67 tests green.

**M8 plan, remaining steps (agreed 2026-10-24, do one at a time):**
Step 3 is in progress: `TRACEUITests` exists and the audit tab test still fails on Rides and Bike
Dynamic Type findings. Open and recorded as decision 73; the cause is not found yet.
3. Automated accessibility audit: a UI-test target that taps through every screen and runs
   `performAccessibilityAudit` (labels, Dynamic Type clipping, contrast, hit size); fix findings.
4. Dynamic Type at the largest size: render Today, Ride mode, Bike in tests and fix truncation
   (Ride mode speed numeral stays fixed size).
5. Empty / error / populated states on all 18 screens, using the canvas's worst-case data.
6. Airplane mode: review map + place-name offline paths, then the rider taps every tab offline.
7. Crash-log check on the phone and the Mac.
8. Tick the v1 ship checklist in ROADMAP with evidence.
Decided 2026-10-24 (decision 72): S15 weekly summary dropped; no Money prev/next arrows.

**Still to check on the phone (none done yet):** M3 real fuel pump (gloves, locked phone, one
press); M4 two expenses during a ride + km/L by hand; M6 handlebar mount (the UI worked on the
phone; readability, gloved taps, hold-to-stop and Live Activity LOG are open until the mount is
fitted); M5 9:00 document notification; M7 exit timings and airplane-mode replay.

Build order puts ride recording first, deliberately. Everything else in v1 is CRUD,
and CRUD does not surprise anyone at 2am; background location does.

## Known risks, named honestly

- **The author stops using it within three weeks.** Most likely failure mode. No
  amount of code quality compensates. Success is measured by capture rate and week-8
  retention, not by shipped features.
- **7-day re-signing friction** may kill the habit, or force the $99 purchase early.
- **Scope creep before v1 ships.** Segments, leaderboards and motion metrics are all
  wanted and all deferred. Building them early is the documented way this project dies.
- **No second opinion.** Owner and user are the same person, which removes discovery
  risk and replaces it with objectivity risk. The decision log is the compensation;
  push back when something looks wrong rather than building it quietly.

## Where everything lives

```
CLAUDE.md                        invariants that must not be violated
CONTEXT.md                       this file
design/DESIGN.md                 frozen tokens, type, components
docs/INDEX.md                    index of all documentation
docs/DECISIONS.md                numbered, append-only decision log
docs/product/PRD.md              full product requirements
docs/product/SCOPE.md            pillars, phasing, privacy rule
docs/product/ROADMAP.md          milestones to v1 and beyond, with exit gates
docs/product/SCREENS.md          every v1 screen, navigation, flows
docs/engineering/ARCHITECTURE.md layers, capture path, GPS strategy, risks
docs/engineering/DATA-MODEL.md   entities, sync fields, fusion rule
docs/engineering/BUILD-PLAN.md   week 1, task by task, with checkpoints
```

Start with `CLAUDE.md`, then `docs/engineering/BUILD-PLAN.md`. Everything else is
reference you read when the task touches it.

## Still unanswered

- The app's actual name. "TRACE" is a placeholder; the bundle id is changeable.
- Whether $99 gets bought on a date or when the friend trial demands it.
