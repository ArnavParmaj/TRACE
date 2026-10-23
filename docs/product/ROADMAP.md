# Roadmap

What gets built, in what order, and what has to be true before moving on.
Milestones are gated by **exit criteria**, not dates. The PRD target is v1 in about
3 weeks of evenings; if a gate fails, the date moves, the gate does not.

Scope comes from `SCOPE.md` and `PRD.md`. Screens come from `SCREENS.md`.
Week-1 tasks are detailed in `../engineering/BUILD-PLAN.md` and not repeated here.

```
v1  ─ M0 ─ M1 ─ M2 ─ M3 ─ M4 ─ M5 ─ M6 ─ M7 ─ M8 ─▶ SHIP v1 ─▶ 8-week dogfood
                                                                    │ gate: still in daily use
v1.5 ─ segments + PBs, gear/mods log, export ◀─────────────────────┘
v2   ─ $99 account ─ Sign in with Apple ─ CloudKit sync ─ friends (TestFlight)
v3   ─ public App Store release
```

---

## v1 — solo, offline, free signing

### M0 · Scaffold — DONE (2026-10-21, commit f5da8e3)
XcodeGen project, Info.plist keys, empty app launches on the iPhone 16.

### M0.5 · App Groups spike — DONE (2026-10-21): they work on free signing, decision 39
Throwaway widget extension with an App Group; try to sign it on the free account.
- **Exit:** result recorded in `DECISIONS.md` (works, or the exact error). Target deleted.
- **Decides:** whether the Control Center control and any widget are in v1 at all.

### M1 · Foundation — models, repositories, tokens — DONE (2026-10-21)
All entities from `DATA-MODEL.md`, `SyncScope`, `CurrentUser` + local stub,
owner-scoped repository, the hand-written token file, bundled fonts
(Oswald, Roboto Condensed), root tab shell with four empty tabs.
- **Exit:** unit tests green on soft-delete exclusion, ownerID scoping, paise arithmetic.
  App launches to the empty tab shell on `#000000`.

### M2 · Recorder — the risky one — DONE (2026-10-23)
Passed on a real 78-min, 31 km ride: force-killed and resumed with ≤6 s lost, GPS at
1 Hz throughout, battery 6.9%/h (decision 55). Results: `engineering/M2-RIDE-TEST.md`.
Built: `TRACE/Recorder/` + debug screen on TODAY (start / pause / resume / stop, haptics),
a plain read-only ride list on RIDES (stand-in until S06 in M7, decision 53),
30 tests green, simulator ride with
background recording and kill/recovery checked. Exit procedure: `engineering/M2-RIDE-TEST.md`.
Accuracy tiering not needed at the measured drain (decisions 45, 55).
`LocationService`, `RideRecorder` (start / stop / 15s autosave / recovery),
`CMAltimeter`, raw `StopEvent`s, polyline encoding, stationary auto-close (30 min within 50 m, decision 50; was 10 min).
Minimal debug UI only: a start/stop button and live numbers.
- **Exit:** a real ride over an hour, force-killed mid-ride, recovered with ≤15s missing.
  Battery drain per hour measured and written in `DECISIONS.md`.
- **If this fails, stop.** Nothing later matters until it passes.

### M3 · Today + capture — CODE DONE (2026-10-23), awaiting real-pump exit test
Built: `TRACE/Capture/` (`Capture` service, `LogEntryIntent`), Today 01 RIDE + 02 DRAFTS,
S08 draft sheet with keypad and queue walk. Decisions 57–59.
Today screen (S02), Action Button `LogEntryIntent` → `CaptureDraft`, draft list on
Today, draft-completion sheet (S08) promoting a draft to an `Expense`.
- **Exit:** a real fuel fill logged at a real pump, gloves on, phone locked, one press.
  Completed later from Today in under 15 seconds.

### M4 · Money + fusion — CODE DONE (2026-10-24), awaiting exit test
Built: `TRACE/Money/Ledger.swift` (fusion, attach/detach, km/L), shared S08 editor
(`ExpenseSheet`: draft, new, edit, delete), Money tab (S10), `RideSheet` (S05 recap +
S07 cost), tap-through and ₹ spent on RIDES. Decision 64.
Expense editor with fuel fields, the fusion rule on ride close, km/L between
consecutive full-tank fills (partials flagged, excluded), Money tab (S10),
fused expenses on the ride recap.
- **Exit:** a ride with two logged expenses closes and shows both attached and the
  correct total. Detaching one moves it back to unattached. km/L matches a hand calc.

### M5 · Bike ops — service + documents + notifications — CODE DONE (2026-10-23), awaiting exit test
Built: `TRACE/Bike/` (`Due`, `Garage`, `Reminders`), Bike tab, S12/S13/S14 sheets, Today 03 DUE.
Decisions 60–61.
Bike tab (S11), odometer sheet (S14), service tasks with computed due state (S12),
mark-done → `ServiceEvent` (+ paired local-only `Expense` if cost given),
documents with expiry and attachment (S13), local notifications for both.
Trip meters A and B on S11: resettable distance counters like a bike's own, summed
from rides since each reset (decision 56).
- **Exit:** real tasks and documents entered for the actual bike. A test document
  expiring tomorrow fires its notification. An overdue task shows the alarm rail.

### M6 · Ride mode + Live Activity
Ride mode (S03) per artboard F, tap-anywhere capture, hold-to-stop, screen kept awake,
Live Activity (S18) with elapsed time, distance and a log button.
- **Exit:** a ride with the phone on the handlebar mount: numbers readable at a glance
  in daylight, a draft logged by tapping with gloves, the ride stopped without
  looking twice. No accidental stops.

### M7 · Review — replay, charts, summaries
Rides tab (S06), ride detail with map replay, offline no-basemap fallback, elevation
profile and splits (S07), route line coloured by speed slow → moderate → fast (decision 56),
top speed marker, speed bands, stops, ride-level personal bests, place names (decision 62), trend charts on Rides and Money, weekly summary (S15),
per-trip recap (S05).
- **Exit:** "what did the last trip cost?" answered from a cold open in under 10 seconds.
  Ride detail renders a 200 km ride in under 2 seconds. Replay works in airplane mode.

### M8 · Ship hardening
Onboarding (S01), Settings with vehicle picker (S16), empty/error states on every
screen, Dynamic Type pass at the largest sizes, VoiceOver labels, airplane-mode test of
every screen, `NSFileProtectionComplete` on the store, a crash-log check.
- **Exit:** the v1 ship checklist below is all ticked.

### v1 ship checklist
- [ ] Every PRD "Must" feature works on device
- [ ] Every screen in `SCREENS.md` (v1 rows) has empty, error and populated states
- [ ] Airplane mode: every screen works
- [ ] Largest Dynamic Type size: nothing truncated on Today, Ride mode, Bike
- [ ] Zero rides lost across all test rides
- [ ] No hardcoded hex in any view; red appears only on overdue/expired/urgent
- [ ] Docs match code (`CONTEXT.md` "where things stand" updated)

---

## Dogfood — 8 weeks after v1 ships
No new features. Fix bugs, tune thresholds, measure against PRD §2:
capture rate ≥85%, fuel logged within 60s ≥90%, used 5 of 7 days in week 8.
- **Gate to v1.5:** the author is still using it in week 8. If not, find out why
  before adding anything. More features do not fix a habit that did not form.

## v1.5 — only after the dogfood gate
- Stop classification (toll / signal / fuel) tuned on 4–6 weeks of real `StopEvent`s
  (decision 30)
- Segments and personal bests (local route matching)
- Gear and modifications log
- CSV / JSON export (rides and service; money export stays on-device)
- Richer trends

## v2 — needs the $99/yr Apple Developer Program
Trigger is open (PRD Q7): a date, or when the friend trial demands it.
- Sign in with Apple; swap the `CurrentUser` stub for a real account
- CloudKit sync of syncable models only. `Expense` never syncs.
- TestFlight to 3–5 riding friends
- Selective ride sharing, home start/end fuzzing, friend leaderboards
- **Gate to v3:** 3 of 5 friends still logging after 4 weeks

## v3 — public release
App Store listing, privacy policy, App Review justification for background location,
data-deletion flow, onboarding for people who are not the author, a revenue answer
(PRD Q11). Apple Watch and ride-quality metrics only if demand appears.

---

## Open decisions by milestone
| Needed by | Decision | Where |
|---|---|---|
| v1 scope | Schedule a Control Center control or widget? (now possible) | decision 39 |
| M5 | Due-soon threshold (U4) | SCREENS §Open |
| M6 | Hold-to-stop duration and gesture (U3) | SCREENS §Open |
| v1 ship | App name (bundle ID, wordmark) | PRD Q2 |
| v2 | When to buy the $99 account | PRD Q7 |
| v2 | Friends' route visibility default | PRD Q12 |
