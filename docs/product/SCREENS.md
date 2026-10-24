# Screens and flows — v1

Every screen in v1, what is on it, how it behaves, and how the user moves between them.
Visual language (tokens, type, components) is `../../design/DESIGN.md` and is not
repeated here; this doc says *what* goes where, DESIGN says *how it looks*.

**Prototype:** a clickable canvas of 9 boards (Today, Rides, Money, Bike, Ride mode,
Recap, Ride detail, Expense editor, tab bar) in the frozen tokens:
https://claude.ai/artifact/MTdvxrwvJhGdanmtdvQe9Q (private to the owner). Today and Bike
have a `data` tweak: demo / worst / empty. It is a design reference, not app code.

**Artboards:** E (Today) and F (Ride mode) are the visual source of truth for those two
screens and go in `design/artboards/`. Until they are exported there, S02 and S03 below
are written from `DESIGN.md` alone. **When the artboards land, they win, and this doc
gets fixed to match.**

---

## 1. Global UX rules
These apply to every screen. A screen spec below only notes exceptions.

1. **Gloves.** Every tappable thing is ≥60pt tall. No swipe-only actions; swipes are
   shortcuts for something also reachable by a tap. No long text fields while moving.
2. **True black, few lit pixels.** Outlines, not filled buttons. One primary action per
   screen gets the amber border; everything else is ink-on-black.
3. **Red means trouble.** `--alarm` / `--alarm-ink` only for overdue, expired, urgent or a
   destructive confirm. Due-soon is amber (`--accent`), expiry countdowns are `--warn`.
4. **Numerals are Oswald.** Every number: speed, km, ₹, dates in stat displays.
5. **Money is formatted at the view only.** Views receive paise `Int`, format with the
   locale `NumberFormatter`. No arithmetic in views.
6. **Never colour alone.** Every red/amber state also has text (`OVERDUE`, `DUE IN 120 KM`).
7. **Every list screen has three states:** empty (what to do to fill it), populated, and
   error (what failed, one retry action). Loading is near-instant from the local store,
   so no spinners; if something is slow, show the layout with `--ink-faint` placeholders.
8. **Soft delete with undo.** Delete hides the row and shows an undo bar for 5s.
   Nothing is hard-deleted from the UI.
9. **Haptics** (decision 52). Every button gives a light tap on touch-down, so a gloved
   press is felt. Ride start / resume / stop and capture give a success haptic, pause a
   heavy tap, destructive confirm a warning. One haptic per press: a button whose outcome
   has its own haptic skips the light tap.
10. **Strings through `String(localized:)`**, units through formatters, from day one.
11. **No translucent materials.** Bars and sheets are solid `--ground` with a hairline edge.
    Blur over black buys nothing and lights pixels.

---

## 2. Navigation map
Decision 32: custom four-tab bar, ≥60pt tall (the stock bar is 49pt).

```
                        ┌─────────── Action Button (any time, locked or not)
                        │               └─▶ CaptureDraft written, no UI
                        ▼
 Launch ─▶ [S04 Recovery?] ─▶ Tab bar
 (first run ─▶ S01 Onboarding)
 ┌──────────────┬──────────────┬──────────────┬──────────────┐
 │ TODAY  S02   │ RIDES  S06   │ MONEY  S10   │ BIKE   S11   │
 ├──────────────┼──────────────┼──────────────┼──────────────┤
 │ Start ride ─▶│ Ride ─▶ S07  │ Expense ─▶S08│ Odometer ▶S14│
 │   S03 Ride   │  detail      │  editor      │ Task ─▶ S12  │
 │   mode       │              │ + Add ─▶ S08 │  └ Done ▶ S09│
 │ Draft ─▶ S08 │              │              │ Doc ─▶ S13   │
 │ Due item ─▶  │              │              │              │
 │   S12 / S13  │              │              │              │
 │              │              │              │              │
 │ ⚙ ─▶ S16     │              │              │              │
 └──────────────┴──────────────┴──────────────┴──────────────┘
 S03 Ride mode ─(stop)─▶ S05 Ride recap ─▶ S07 Ride detail
 Outside the app: S17 Notifications, S18 Live Activity
```

- Ride mode (S03) is a full-screen cover over the tabs, not a tab. The tab bar is hidden.
- Sheets (S04, S08, S09, S14) open as bottom sheets with a ≥60pt close/confirm row.
- Settings (S16) opens from a ⚙ button top-right of Today.

---

## 3. Screen inventory
| ID | Screen | Type | Phase | Milestone | Entry points |
|---|---|---|---|---|---|
| S01 | Onboarding | full screen, 3 steps | v1 | M8 (built, decision 67) | first launch, Bike tab empty, Settings + ADD BIKE |
| S02 | Today | tab root | v1 | M3 | app launch, tab |
| S03 | Ride mode | full-screen cover | v1 | M6 (built, decision 68) | Start ride on Today, Live Activity |
| S04 | Ride recovery | sheet | v1 | M2 | launch with an open ride |
| S05 | Ride recap | sheet | v1 | M4 (built) | ride stop |
| S06 | Rides | tab root | v1 | M7 (plain stand-in list since M2, decision 53) | tab |
| S07 | Ride detail | sheet | v1 | M7 (built) | S05, S06, Money rows |
| S08 | Expense editor | sheet | v1 | M3 | draft, + Add, any expense row |
| S09 | Mark service done | sheet | v1 | M5 | S12, notification |
| S10 | Money | tab root | v1 | M4 | tab |
| S11 | Bike | tab root | v1 | M5 | tab |
| S12 | Service task | push | v1 | M5 | S11, Today due list, notification |
| S13 | Document | push | v1 | M5 | S11, Today due list, notification |
| S14 | Odometer update | sheet | v1 | M5 | S11, S05 |
| S15 | Weekly summary | — | dropped (decision 72) | — | — |
| S16 | Settings | sheet | v1 | M8 (built, decision 67) | ⚙ on Today |
| S17 | Notifications | system | v1 | M5 | — |
| S18 | Live Activity | system | v1 | M6 (built, decision 68) | ride start |
| — | Control Center control, widget | system | unblocked, not scheduled | — | decision 39 |

**Not in v1:** segments, gear/mods, export, sharing, friends, accounts. No screens for
them, no placeholders, no "coming soon" rows.

---

## 4. Screen specs

### S01 · Onboarding
Three steps, one question each, a ≥60pt NEXT at the bottom.
1. **Your bike** — name, make/model (optional), registration (optional).
2. **Odometer** — current reading, numeric keypad, big Oswald display.
3. **Permissions** — explains *why* before asking: location "While Using" first, then
   "Always" is requested at the first ride start (iOS shows it contextually), motion,
   notifications. Also states plainly: *no account, no cloud backup, data stays on this
   phone* (PRD §3).
- Skippable except step 1. Lands on Today.

### S02 · Today (artboard E)
The hub. Answers "what's happening, what's waiting, what's due" in one scroll.

```
TRACE                         TUE 21 OCT   ⚙
01 RIDE ────────────────────────────────────
┃ START RIDE                          (capture button, 106pt)
┃ CB350 · ODO 12,480 KM
   — when a ride is live, this section becomes:
┃ RIDING  00:42:10   23.4 KM   → OPEN RIDE MODE
02 DRAFTS ───────────────────────────── 2 ──
  14:02  Fuel?  near Khopoli          COMPLETE ›
  13:20  Draft  near Lonavala         COMPLETE ›
03 DUE ─────────────────────────────────────
┃ PUC  EXPIRED 3 DAYS AGO              (alarm rail)
  CHAIN LUBE  DUE IN 120 KM  ▬▬▬▬▬▬▬──  (amber progress)
  INSURANCE  41 DAYS                    (warn chip)
04 THIS WEEK ───────────────────────────────
  M  T  W  T  F  S  S     (week strip, ride days marked)
  142 KM   ·   ₹1,240   ·   34.1 KM/L          ›
05 RECENT ──────────────────────────────────
  SAT  Mumbai → Lonavala   86.4 KM   ₹480      ›
  FRI  Fuel   ₹410   4.1 L  FULL               ›
```
- **Sections hide when empty** except 01. With no drafts and nothing due, Today is short.
- 03 DUE shows overdue (alarm rail) + due-soon only; "fine" items live on the Bike tab.
- Due-soon threshold: within 15% of interval or 14 days (tunable in Settings).
- 02 DRAFTS shows at most 3 rows, then "ALL 14 DRAFTS ›". Completing walks the queue
  draft by draft (SAVE moves to the next), so 14 drafts never means 14 round trips.
- Empty first-run state: 01 plus a single line under it, "Press the Action Button any
  time to log. Start a ride here."

### S03 · Ride mode (artboard F)
Handlebar screen. Portrait only (decision 34). Lights as few pixels as possible.
Screen kept awake while this is foregrounded (`isIdleTimerDisabled`).

```
┌──────────────────────────────┐
│ ● REC              00:42:10  │  ink-faint, small
│                              │
│            48                │  speed, huge Oswald, --ink
│           KM/H               │  inside a 4px gauge arc
│                              │
│   23.4 KM        +312 M      │  distance · climb, Oswald
│                              │
│      TAP ANYWHERE TO LOG     │  ink-faint
│                              │
│ ─────── HOLD TO STOP ─────── │  bottom band, ≥100pt
└──────────────────────────────┘
```
- **Tap anywhere** above the stop band → writes a `CaptureDraft` tied to this ride,
  success haptic, a 1s amber flash on the REC dot. No sheet, no confirmation.
- **Hold the stop band 2s** → progress bar fills along the band → ride stops → S05.
  Release early cancels. No tap-to-stop, ever.
- No map. A map lights the whole screen and is not readable at a glance.
- The REC dot is amber, not red: recording is live state, not an emergency (rule 3).
- GPS lost: speed shows `--` in `--ink-faint` and a small `NO GPS` label. Not red;
  it is not the rider's emergency.
- Top-left `‹` (≥60pt) returns to Today without stopping the ride.

### S04 · Ride recovery (decision 25)
Shown on launch when a ride is still marked recording and the recorder is not running.
- Text: "A ride from 08:14 didn't finish. 38.2 km saved up to 10:02."
- **RESUME** (primary, amber) — continues recording into the same ride.
- **END AT 10:02** — closes the ride at its last autosave → S05.
- Never auto-discards. No third "delete" button here; delete lives on S07.

### S05 · Ride recap
Built in M4 as `RideSheet` (decisions 64, 65). Odometer prompt is ENTER → S14.
Shown once, right after a ride stops. The fusion moment.
- Headline: place → place, date. Stat row: distance, moving time, climb, ₹ total.
- **Attached expenses** (fused automatically) with a DETACH action per row.
- Unclassified drafts from this ride: "2 drafts from this ride" → complete each (S08).
- Odometer prompt: "Odometer now? Suggested 12,566" → S14. Skippable (decision 24:
  manual is authoritative, GPS only suggests).
- **DONE** → Today. **VIEW RIDE** → S07.

### S06 · Rides
- Top: distance chart, last 12 weeks (bars, Swift Charts). Tap a bar to filter to that week.
- PB card: longest ride, top speed, biggest climb, fastest 10 km (decision 62).
- List grouped by month: date, start → end place, km, duration, ₹ total if any, PB badge.
- No search in v1 (decision 62): the chart and month groups find a ride.
- Empty: "No rides yet. Start one from Today."

### S07 · Ride detail
Built (M4 + M7, `RideSheet`): map, 01 STATS, 02 ELEVATION, 03 SPEED (bands, top, stops), 04 SPLITS,
05 COST, DELETE RIDE. The odometer shows as one line under 01 STATS, "ODO a → b KM", not a 05 BIKE section (decision 71).
```
‹ RIDES                      SAT 18 OCT
[ map with route polyline, ~40% height ]   offline → polyline on black, no basemap
                                          line coloured by speed (decision 56)
01 STATS ──────────────────────────────
  86.4 KM   2:14 MOVING   2:51 ELAPSED
  +624 M    38 AVG        92 MAX KM/H
02 ELEVATION ──────────────────────────
  [ elevation profile chart ]
   TOP SPEED 92 KM/H (marked on map)   PB
   <40 ▬▬▬▬ 40–80 ▬▬▬▬▬▬▬ >80 ▬▬  (time in speed bands)
   7 STOPS · 0:37 STOPPED   (stops marked on map with duration)
03 SPLITS ─────────────────────────────
  KM 1–10   0:14   avg 43   …
04 COST ───────────────────── ₹480 ──
  Fuel  ₹410  4.1 L  FULL       ›
  Chai  ₹70                      ›
  + ATTACH AN EXPENSE
  13.9 KM/L (full-tank to full-tank)
05 BIKE ───────────────────────────────
  ODO 12,480 → 12,566          EDIT
                       DELETE RIDE (soft, undo)
```
- Offline basemap fallback is a designed state, not an error: polyline drawn on
  `--ground` with start/end markers and a small `OFFLINE MAP` slug.
- No replay animation in v1 (decision 62). Ghat / section timing is v1.5.

### S08 · Expense editor
One sheet for three jobs: completing a draft, adding a new expense, editing one.
1. **Category grid** first (if not already known): FUEL full width (72pt, the common
   case), then FOOD / PARTS / PARKING / OTHER in a 2×2 grid, each ≥60pt. Tolls are out of
   scope (decision 37).
2. **Amount**: big Oswald display + numeric keypad pinned at the bottom of the sheet.
   Entered as rupees (max 2 decimals, max ₹99,99,999), stored as paise.
3. **Fuel extras** (only if Fuel): litres; price/L is derived from amount ÷ litres, never
   typed (decision 58). FULL TANK toggle (default on), odometer (optional).
4. Optional note (one line). Time defaults to the draft's capture time.
5. **SAVE** (primary). Draft is promoted and removed from the queue.
- **DISCARD DRAFT** (secondary) for accidental presses.
- Fusion is shown, not hidden: "Attached to ride: Mumbai → Lonavala" with DETACH.
- Partial fill note: "Partial fills are logged but not used for km/L" (decision 26).

### S09 · Mark service done
Date (default today), odometer (default current), cost (optional), notes (optional).
SAVE writes a `ServiceEvent`; if cost is given, also a local-only `Expense`.
The task's due state recomputes immediately.

### S10 · Money
```
MONEY                      [ WEEK | MONTH | YEAR ]
  ₹4,860                   this month
01 BY CATEGORY ────────────────────────
  Fuel   ▬▬▬▬▬▬▬▬▬▬▬▬  ₹3,280
  Food   ▬▬▬▬          ₹890
  Parts  ▬▬            ₹450   …
02 FUEL ECONOMY ───────────────────────
  [ km/L line chart, full-tank intervals only ]
  34.1 KM/L latest · partial fills excluded
03 ENTRIES ────────────────────────────
  SAT  Fuel  ₹410  · Lonavala ride       ›
                                  + ADD EXPENSE
```
- Category bars use `--ink-dim` on the unlit track; no rainbow palette.
- Expense rows linked to a ride show the ride name and open S07 on tap of that label.
- Empty: "Nothing logged. Press the Action Button at your next fill."

### S11 · Bike
```
CB350 · MH 02 AB 1234
  ODO 12,480 KM                    UPDATE ›   (→ S14)
  TRIP A 342.6 KM   TRIP B 31.0 KM   (hold to reset)
01 SERVICE ────────────────────────────
┃ CHAIN LUBE  OVERDUE BY 80 KM         ›    (alarm rail)
  OIL CHANGE  DUE IN 1,520 KM ▬▬▬▬──   ›
  BRAKE PADS  OK                        ›
                                  + ADD TASK
02 DOCUMENTS ──────────────────────────
┃ PUC  EXPIRED 3 DAYS AGO               ›
  INSURANCE  41 DAYS  (warn chip)       ›
  RC  2034                              ›
                              + ADD DOCUMENT
```
- Sorted most-urgent first. Due state computed on render (invariant 6).
- Trip A / B (decision 56): sum of ride distance since each reset, computed on render.
  Only the reset time is stored. Reset is hold-to-confirm, so a gloved brush can't wipe it.
- One vehicle shown. Switching the primary vehicle lives in Settings (decision 28).

### S12 · Service task
Name, kind, interval km and/or days, last done (odo + date), computed status with a
progress bar, history of `ServiceEvent`s with cost. **MARK DONE** (primary) → S09.
Edit and deactivate (soft) at the bottom.

### S13 · Document
Kind, identifier, issued / expires dates, reminder lead times (chips: 30, 7, 1 days),
attachment (photo or PDF from Files, stored in the app container only, never Photos).
**RENEWED** (primary) → asks for the new expiry date, keeps the old record as history.

### S14 · Odometer update
Big Oswald display + keypad. Shows the GPS-summed suggestion and the last manual value.
Rejects a value lower than the last reading unless confirmed ("odometer replaced?").

### S15 · Weekly summary — dropped (decision 72)
Not in v1. Today's THIS WEEK and the Rides chart cover the week.

### S16 · Settings
- Vehicles: list, add, set primary (picker, decision 28)
- Units (metric default), currency (INR default)
- Notification lead times: service due-soon threshold, document reminder defaults
- Data: storage used, route-sample retention note (decision 27)
- About: version, "data never leaves this phone", decision-log link for the curious

### S17 · Notifications (local only)
| Trigger | Text | Tap opens |
|---|---|---|
| Service becomes due-soon | "Chain lube due in 120 km" | S12 |
| Service overdue | "Chain lube overdue" | S12 |
| Document reminder (lead times) | "PUC expires in 7 days" | S13 |
| Document expired | "PUC expired today" | S13 |
| Ride auto-closed (decision 50) | "Ride ended after 30 min stopped. 38.2 km saved." | S05 |
Km-based reminders can only be scheduled when the odometer moves, so they are
re-evaluated after each ride and each odometer update, not at a fixed time.

### S18 · Live Activity (lock screen + Dynamic Island)
Elapsed time, distance, REC dot. One **LOG** button running the same App Intent as the
Action Button. Tap elsewhere opens Ride mode. State is pushed from the app via
ActivityKit local updates (no push entitlement). Signs on the free team (decision 68); on-device check is the M6 exit.

---

## 5. Key flows

**F1 · Fuel at the pump (the thesis).**
Gloves on, phone locked → press Action Button → haptic → done (<2s). Later, on Today:
02 DRAFTS → COMPLETE → Fuel → ₹410 → 4.1 L → SAVE. The expense lands inside the ride if
one was running, else unattached until a ride window covers it.

**F2 · A ride, start to finish.**
Today → START RIDE → (first time: "Always" location prompt) → Ride mode → tap to log
drafts on the way → hold STOP 2s → Recap: attached expenses, drafts to complete,
odometer prompt → DONE.

**F3 · Force-kill or crash mid-ride.**
Relaunch → S04 → RESUME or END AT last autosave. Never silently discarded.

**F4 · Forgot to stop.**
30 min stationary (within 50 m, decision 50) → ride auto-closes at the moment it stopped moving → notification →
recap on next open.

**F5 · Service due.**
Notification "Chain lube due" → S12 → MARK DONE → S09 (odo prefilled, cost optional) →
task resets, Today's 03 DUE clears.

**F6 · Document renewal.**
Today 03 DUE alarm rail "PUC expired" → S13 → RENEWED → new expiry → attach the new
certificate photo → reminders reschedule.

**F7 · First launch.**
S01 bike → odometer → permissions → Today (empty state).

---

## 6. Interaction, motion and haptics
Decision 38: motion is **functional only**. It confirms an action or keeps a change from
being jarring; nothing loops, nothing decorates. Sources: apple-design (WWDC fluid
interfaces), emil-design-eng (frequency and easing rules).

**Should it animate?** Decide by how often the user sees it.
| Thing | Seen | Motion |
|---|---|---|
| Tab switch | tens of times a day | 180 ms crossfade + 28pt slide toward the tapped tab; fade only under Reduce Motion (decision 63) |
| List rows appearing | many times a day | none, no stagger |
| Live numbers in Ride mode | every second | none; tabular figures so digits don't jitter |
| Press feedback (every button) | constant | scale 0.97 on touch-down, ~120ms |
| Sheets (S04, S08, S09, S14) | occasional | system sheet: drag-to-dismiss, velocity-aware, interruptible |
| Push to detail | occasional | system navigation push |
| Capture confirm (Ride mode tap) | per log | 1s amber "DRAFT LOGGED · n" + success haptic, same frame |
| Hold-to-stop | per ride | fill over 2s linear while held; snaps back in 200ms on release |
| Map replay along route | rare, opt-in | allowed; off under Reduce Motion |

**SwiftUI mapping.**
- Use system `.sheet` with detents and `NavigationStack` pushes. They are already
  interruptible and velocity-matched; do not hand-roll them.
- One `ButtonStyle` for the whole app: `scaleEffect(isPressed ? 0.97 : 1)` with a
  critically damped spring (`.spring(response: 0.3, dampingFraction: 1)`). Feedback on
  touch-down, not release. Under Reduce Motion, swap scale for a 0.7 opacity dim.
- No bounce anywhere (damping 1.0). Nothing here is flung, so overshoot has no cause.
- Hold-to-stop: a `LongPressGesture(minimumDuration: 2)` driving a progress value; the
  fill uses `scaleEffect(x:anchor: .leading)`, never a width change.
- Ride mode digits: `.monospacedDigit()`. Check Oswald ships tabular figures; if not, give
  each number a fixed-width frame.

**Haptics** (`.sensoryFeedback`). Haptic and visual fire on the same frame, or not at all.
| Event | Haptic |
|---|---|
| Draft logged (Ride mode tap) | `.success` |
| Ride started / resumed / stopped | `.success` (stop: when the hold completes, not when it starts) |
| Ride paused | `.impact(weight: .heavy)` — felt differently from stop |
| Hold-to-stop begins | `.impact(weight: .light)` once |
| Destructive confirm (delete ride, stop ride) | `.warning` |
| Any other button or tab, on touch-down | `.impact(weight: .light)` (decision 52; was "none") |

**Action Button confirmation.** The intent runs without the app, so the rider's
confirmation is the system's own intent result. Verified in M3: a dialog adds a Done
tap, so `LogEntryIntent` returns no dialog and the system ✓ is the confirmation (decision 57).

**Type tracking.** Large Oswald numerals get slightly negative tracking (about −0.02em);
caps labels get positive tracking (0.1–0.2em); body Roboto Condensed stays at 0.
Use `Font.custom(_:size:relativeTo:)` so labels follow Dynamic Type; the Ride mode speed
numeral is fixed size (it is already the largest thing on screen).

---

## 7. Worst-case data rules
From a break-ui pass on the prototype (`data = worst`). Each is a rule for the real views.

| # | Case | Rule |
|---|---|---|
| W1 | ₹1,04,250 and 1,02,345 km | Indian digit grouping: format with the device locale (`en_IN`), never a hand-rolled comma every 3 digits. |
| W2 | "Chhatrapati Shivaji Maharaj Terminus → Mahabaleshwar–Panchgani Road via Tamhini Ghat" | Lists clamp place names to 2 lines; Ride detail and Recap show them in full. Amounts never truncate. |
| W3 | "INSURANCE — COMPREHENSIVE (OWN DAMAGE + THIRD PARTY)" | Labels wrap; status text never shrinks and never wraps (`fixedSize`). On alarm rails, status sits on its own line. |
| W4 | 14 unfinished drafts | Today shows 3 + "ALL 14 DRAFTS"; completion walks the queue. |
| W5 | 1 draft, 1 ride | Plurals via String Catalog plural rules ("1 DRAFT", not "1 DRAFTS"). |
| W6 | No two full-tank fills yet | km/L shows "— KM/L" plus one line: "needs two full-tank fills in a row". Never 0.0 and never a guess. |
| W7 | Draft captured with no GPS fix | Row reads "no location · GPS unavailable"; the draft still saves (invariant 7). |
| W8 | "Royal Enfield Himalayan 450 Kaza Brown" | Bike name wraps in the Bike header; Today's capture subline may wrap too. |
| W9 | 1 km left on a task | "1 km left" is due-soon (amber), not OK. Due-soon is computed, so this follows from U4. |
| W10 | Faint grey `#6E6B67` on black ≈ 3.9:1 | Never for text the rider must read. Readable small text uses `--ink-muted` or lighter. Faint is for slugs, separators and non-essential state only. |

---

## 8. Open UX decisions
Raised, not decided. Each needs an answer before the milestone listed.

| # | Question | Proposal | Needed by |
|---|---|---|---|
| U1 | ~~Capture button red spine~~ | **Resolved:** amber spine (decision 36). | — |
| U2 | ~~Expense categories~~ | **Resolved:** Fuel, Food, Parts, Parking, Other; tolls out of scope (decision 37). | — |
| U3 | Hold-to-stop duration. | 2 seconds on a ≥100pt bottom band. Tune on the M6 ride. | M6 |
| U4 | ~~Due-soon threshold~~ | **Resolved:** 15% default, 5–30% in Settings, 14-day cap (decision 67). | — |
| U5 | What can a draft become besides an expense? | v1: expense or discard only. "Mark this spot" waits for real need. | M3 |
| U6 | Ride mode main number: speed or distance? | Speed in the gauge; distance and climb below. Check against artboard F. | M6 |
