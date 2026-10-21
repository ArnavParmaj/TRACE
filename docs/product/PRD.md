# TRACE — Product Requirements Document

**Version** 1.0 · **Date** 2026-10-21 · **Owner** Arnav Parmaj · **Status** Approved for build

---

## 1. Executive Summary

### Problem statement
A motorcyclist's life generates three streams of data that never meet. The ride
itself (route, distance, time) lives in Strava or nowhere. The money (fuel, tolls,
roadside chai, new sprocket) lives in a bank app, a Notes file, or memory. The bike's
upkeep (chain lube at 500 km, oil at 5,000, PUC expiring next month) lives in a
mechanic's head and a glovebox full of paper.

The result is three specific failures, observed in the target user's own behaviour:

1. **Capture fails at the moment of truth.** Logging a fuel fill requires unlocking a
   phone, finding an app, and typing — while wearing gloves, at a pump, with a queue
   behind. So it does not happen. It gets reconstructed at night, badly, or not at all.
2. **Questions that should be trivial are unanswerable.** "What did the Lonavala trip
   actually cost me?" requires cross-referencing a route app against a bank statement
   against memory. Nobody does this, so nobody knows.
3. **Maintenance is reactive.** Chain wear and document expiry are both pure arithmetic
   on numbers the rider already has — odometer and dates — yet both are discovered
   late, at cost. An expired PUC in Maharashtra is a fine; a dry chain is a sprocket.

Existing tools each own one slice and refuse the others. Strava is a social
performance network that does not know what fuel costs. Fuelio and Drivvo track fuel
and service but have no real route capture and dated interfaces. Splitwise knows
money and nothing else. No tool joins a route to the spending that happened during it.

### Proposed solution
An offline-first iOS app for motorcyclists built around three commitments:

- **Zero-friction capture.** One press of the iPhone 16 Action Button writes a log
  entry and returns immediately — no unlock, no form, no network. Completion of
  details happens later, when stopped. The tap always succeeds.
- **Automatic fusion.** When a ride ends, every expense logged inside its time window
  attaches to it. The Lonavala trip becomes one object: 86.4 km, 2h 14m, 624 m of
  climb, ₹480 spent, 13.9 km/L. No app currently produces this object.
- **Arithmetic that works for you.** The odometer already drives service intervals;
  dates already drive document expiry. Both become local notifications. No
  intelligence required, just discipline the rider does not have to supply.

Everything runs on-device. No account, no server, no network dependency — which is
what a Spiti or Konkan run actually demands, and what the free signing tier enforces.

### Why now
- **The hardware arrived.** The Action Button (iPhone 15 Pro, all iPhone 16 models)
  is the first iOS affordance that makes gloved, eyes-free capture genuinely possible.
  Control Center controls and App Intents (iOS 18) complete the path. This product was
  not buildable two years ago.
- **The platform caught up.** SwiftData, ActivityKit Live Activities and Swift Charts
  remove most of the infrastructure a solo developer previously had to write.
- **The user problem is current and personal.** The builder is the user, rides
  regularly, and currently hand-logs in Notes. Build-for-yourself is the only
  validation available at this stage, and it is a real one.
- **The India-specific gap is unserved.** PUC, insurance and RC expiry tracking is a
  genuine recurring pain for every Indian two-wheeler owner, and no polished app
  addresses it. It is also nearly free to build.

---

## 2. Goals & Success Metrics

This is a personal product first, with a credible path to public release. Standard
SaaS KPIs (DAU, NPS, MAU) are meaningless at n=1 and are therefore **not** the v1
measures — adopting them would be theatre. The v1 question is narrow and answerable:
*does this replace hand-logging for its own author?* Public metrics activate at v2.

### Business goals
1. **Replace manual logging entirely for the primary user within 8 weeks of install.**
2. **Make per-trip true cost answerable in under 10 seconds**, from a cold app open.
3. **Eliminate late discovery of service and document deadlines** across one full year.
4. **Ship a v1 within 3 weeks of build start** — scope discipline is itself a goal, as
   the dominant failure mode for solo projects is unshipped ambition.
5. **Validate with 3–5 riding friends by v2**, establishing whether the fusion concept
   generalises beyond its author.

### KPIs and targets

| KPI | Target | Measured how |
|---|---|---|
| Ride capture rate | >= 85% of rides taken are recorded | rides logged vs. odometer delta over a month |
| Capture latency | < 2s from Action Button press to confirmed write | instrumented locally |
| Fuel logging timeliness | >= 90% of fills logged within 60s of the fill | entry timestamp vs. ride GPS dwell at a fuel stop |
| Self-retention, week 8 | app used on >= 5 of 7 days in week 8 | local usage counter |
| Battery drain, ride mode | <= 12%/hr screen-on, <= 6%/hr backgrounded | manual measurement on a 2h ride |
| Data integrity | 0 rides lost to crash, kill or re-sign | autosave verification |
| Crash-free sessions | >= 99.5% | local crash log |
| Time-to-answer, trip cost | < 10s cold open to per-trip total | stopwatch, self-test |
| Deadline misses | 0 expired documents, 0 overdue services in 12 months | real-world outcome |
| Friend trial retention (v2) | 3 of 5 invitees still logging after 4 weeks | v2 only |

### What failure looks like
Name it now, so it is recognisable later rather than rationalised away.

- **The honest failure:** the author stops using it within 3 weeks and quietly returns
  to Notes. This is the single most likely outcome and the only one that matters.
- Capture takes more than two taps in practice, so it is skipped at pumps.
- Battery drain exceeds ~20%/hr, making it unusable on the long rides it was built for.
- Any ride is ever lost. One loss destroys trust in a logging tool permanently.
- Scope creep: segments, leaderboards or motion metrics get built before v1 ships.
- The app becomes a thing that is *maintained* rather than *used* — a portfolio piece.
  If it is not being used on actual rides, it has failed regardless of code quality.

---

## 3. Target Audience

### Primary segment
Indian urban motorcyclists aged 18–32 who ride both a daily commute and weekend
ghat/highway runs, already track fuel or expenses by hand in a notes app or
spreadsheet, and own an iPhone 15 Pro or newer (Action Button required for the core
interaction). Archetype: the owner-rider who knows their km/L to one decimal place and
is annoyed that no app knows it with them.

### Secondary segment
Small riding groups — 3–8 friends who ride together, split fuel and food informally,
and would compare distances and routes without wanting a public social network. They
arrive at v2 with accounts and selective sharing.

### Explicitly NOT for
- **Car drivers.** Fuel economy framing, service intervals and mount ergonomics are
  motorcycle-specific. Supporting cars would dilute every screen.
- **Cyclists.** No fuel, no odometer, no service intervals — a different app wearing
  the same words.
- **Fleet operators and delivery riders.** They need multi-rider dashboards,
  compliance exports and driver accountability. That is a B2B product with a server.
- **Strava's actual audience.** Riders who want kudos, segments against strangers and
  a public feed. The social graph is explicitly rejected in v1 and deliberately
  limited in v2.
- **Users expecting cloud backup in v1.** There is none. State it in onboarding.
- **Android users.** The entire capture premise is an Apple hardware affordance.

---

## 4. Scope

### In scope for v1.0
| Feature | Why it is in |
|---|---|
| One-press capture via Action Button | The product thesis. Without it this is just another form-filling app. |
| Capture drafts (log now, complete later) | Makes capture non-blocking, which is what makes it survive gloves and queues. |
| Ride recording: GPS route, distance, duration, barometric climb, speed | The spine. Everything else attaches to a ride. |
| Ride mode screen (artboard F) | Mount-readable, minimal lit pixels, tap-anywhere logging. |
| Today screen (artboard E) | Single surface for live state, recent entries, due items. |
| Expense logging with fuel detail (litres, price, full-tank flag) | Full-tank entries are the only honest basis for km/L. |
| Automatic ride-expense fusion | The differentiator. Two lines of predicate, enormous payoff. |
| Service tasks with due-by-km and due-by-date | Pure arithmetic on data already captured. |
| Document expiry tracking (insurance, PUC, RC, DL) | Highest value-per-hour feature in the build. India-specific gap. |
| Local notifications for service and expiry | Works without push entitlement on free signing. |
| Map route replay with elevation profile | The payoff for recording; also the Strava-equivalent moment. |
| Swift Charts trends (distance, spend, km/L) | Makes a month of data legible. |
| Weekly and per-trip auto summaries | Answers "what did that trip cost" without manual work. |
| Multi-vehicle support (data model + picker) | Cheap now, a migration later. |

### Out of scope for v1.0
| Excluded | Reason |
|---|---|
| Any backend, account or login | Free signing grants no CloudKit; a server contradicts offline-first and costs weeks. |
| Friend sharing, leaderboards, ride feed | All require sync. Deferred wholesale to v2 with the $99 account. |
| Segments and personal bests | Local-only and genuinely wanted, but route-matching is a real algorithm. v1.5. |
| Gear and modifications log | Plain CRUD with no urgency. v1.5. |
| Ride quality metrics (lean angle, braking, vibration) | A new CoreMotion subsystem, worst battery cost, least proven value. |
| Widget / Control Center control | Blocked pending the App Groups spike; Action Button covers the need. |
| Android, iPad, Apple Watch | Watch is tempting and wrong — it doubles surface area before v1 proves itself. |
| Offline basemap tiles | MapKit offers no sanctioned offline tile cache. See Dependencies. |
| Expense splitting between riders | Money never syncs. Splitting inherently requires sharing it. |
| CSV/PDF export | Useful, not load-bearing. Early v1.5. |

### Future scope (v2+)
- **v1.5:** segments and personal bests, gear/mods log, data export, richer trends.
- **v2 (requires $99/yr):** Sign in with Apple, CloudKit sync, TestFlight distribution
  to friends, selective ride sharing, friend leaderboards, home-location privacy zones.
- **v3 (public release):** App Store listing, privacy policy, data-deletion flow,
  onboarding for users who are not the author, optional Apple Watch companion,
  ride quality metrics if demand appears.

---

## 5. Assumptions & Constraints

### Technical constraints
- **Free Apple Developer account.** No push, no iCloud/CloudKit, no HomeKit; App
  Groups availability unverified; 7-day re-sign; max 3 sideloaded apps; no
  distribution to other people's devices by any sustainable means.
- **iPhone 16 (non-Pro) is the reference device.** OLED, so true black costs ~no
  power — but no always-on display and no 1 Hz ProMotion, both Pro-only. Battery
  savings must come from lighting fewer pixels and throttling GPS, not from AOD tricks.
- **GPS dominates power draw**, not the screen. Accuracy tiering is mandatory, not an
  optimisation.
- **Background location** needs only an Info.plist background mode — no paid
  entitlement — but is subject to iOS suspension under memory pressure. Autosave
  every 15s is therefore a correctness requirement.
- **MapKit has no official offline tile cache.** Route replay must degrade to a
  basemap-free polyline render when offline.
- **SwiftData is young.** Migration tooling is thinner than Core Data's; the schema
  should be treated as expensive to change after first real data lands.
- **RouteSample is the only unbounded table.** At 1 Hz, a 3-hour ride is ~10,800 rows.
  A retention or downsampling policy will be needed within months.

### Business constraints
- **Budget: ₹0 for v1.** The $99/yr Apple Developer Program is the single unlock for
  v2 and is currently unfunded.
- **Build window: 3 weeks**, against a Computer Engineering course load. Effective
  capacity is evenings and weekends, not full days.
- **Team of one.** No designer, no QA, no second opinion on architecture. The decision
  log exists specifically to compensate for having no one to argue with.
- **No revenue model.** Not needed at v1; must be answered before any public release.

### Known unknowns
- Whether App Groups are available under free provisioning (blocks widget work).
- Whether the author actually sustains usage past week 3 — the core product risk.
- Real battery draw over a 4+ hour ride; all current figures are estimates.
- GPS accuracy through ghat sections and tunnels, and how badly distance drifts.
- Whether automatic ride start/stop detection is reliable enough to trust, or whether
  v1 must require a manual start.
- Whether friends will tolerate an app that needs the author's Mac every 7 days — this
  may force the $99 purchase earlier than planned.
- Whether a Notes-app habit of several years is actually displaceable by better tooling.

---

## 6. Non-Functional Requirements

### Performance
- Cold launch to interactive Today screen: **< 1.2s** on iPhone 16.
- Action Button press to durable write: **< 2s**, and the write must never block on UI.
- Ride mode must sustain **60fps** with GPS recording active.
- Map replay of a 200 km route must render in **< 2s** (polyline downsampled for display).
- Autosave interval: **15s**, so worst-case data loss is bounded and small.
- Charts over 12 months of data: **< 500ms** to render.
- **Uptime SLA: not applicable.** There is no server. The equivalent commitment is:
  the app functions identically in airplane mode, and this is tested as such.

### Scalability targets
- 5 years of personal data: ~5,000 rides, ~15,000 expenses, ~50M route samples before
  any downsampling. Queries must stay indexed on `ownerID` + date.
- Local database target: **< 500 MB at 3 years** with a route-sample retention policy.
- v2 sync design must tolerate 2–8 devices per account, not 8,000. Do not
  over-engineer for scale that will not arrive.

### Security
- All data at rest protected by iOS file-level encryption; database marked
  `NSFileProtectionComplete` so it is unreadable while the device is locked.
- **Expense data is `syncScope = .localOnly`, enforced at the model layer** — not by
  convention. No future sync, export or analytics path may read it.
- No analytics SDK, no crash reporter that transmits, no third-party telemetry. Ever.
- Document attachments (insurance PDFs, RC images) stored in the app container only,
  never in shared storage or Photos.
- v2: Sign in with Apple exclusively. No hand-rolled credentials — it is an App Store
  requirement alongside third-party login and avoids owning a password surface.
- Location data never leaves the device in v1. In v2, only rides the user explicitly
  shares, with home-location fuzzing applied before transmission.

### Accessibility
- **Touch targets >= 60pt** everywhere, exceeding the 44pt HIG minimum, because the
  user is gloved. Ride mode uses tap-anywhere capture with no precision targets.
- Full Dynamic Type support; layouts must survive the largest accessibility sizes
  without truncation (Oswald numerals are the risk area — test early).
- VoiceOver labels on every control; the gauge carries a textual `aria`-equivalent
  value, not just a visual arc.
- Contrast: body text >= 4.5:1 on black; muted labels >= 3:1 and never below 11px.
  `#E0241B` is border-and-fill only — red text uses the lighter `--alarm-ink`.
- No information conveyed by colour alone: due/overdue states carry text and position,
  not just a red rail.
- Reduce Motion respected on map replay animations.

### Localization / internationalization
- **v1 ships English-only, India-only**, and this is a deliberate narrowing rather
  than an oversight.
- All user-facing strings go through `String(localized:)` from day one — retrofitting
  is far more expensive than the near-zero cost of doing it correctly now.
- Currency is `Decimal`-free integer minor units with an ISO code stored per expense;
  display formatting via `NumberFormatter` with locale. Defaults to INR, not hardcoded.
- Units: metric throughout (km, litres, km/L), with the unit system stored as a
  preference so imperial is a formatting change rather than a schema change.
- Dates always via `DateFormatter`; never string-concatenated.
- Document types (PUC, RC) are India-specific and modelled as an extensible enum, so
  other jurisdictions add cases rather than requiring a migration.

---

## 7. Feature List

### Epic A — Capture
| Feature | Priority | Description |
|---|---|---|
| Action Button intent | **Must** | One press writes a CaptureDraft and returns, no unlock required. |
| Capture drafts queue | **Must** | Incomplete entries surface on Today for completion when stopped. |
| Quick expense entry | **Must** | Amount, category, optional note — three taps maximum. |
| Fuel entry with full-tank flag | **Must** | Litres, price, full-tank boolean; only full fills feed km/L. |
| Tap-anywhere logging in ride mode | **Must** | No precision target while moving. |
| Siri / Shortcuts phrase | Should | "Log fuel in Trace" as a hands-free alternative. |
| Control Center control | Nice | Blocked on the App Groups spike; do not build until resolved. |

### Epic B — Ride recording
| Feature | Priority | Description |
|---|---|---|
| GPS route recording | **Must** | CoreLocation with accuracy tiering by foreground state. |
| Barometric climb | **Must** | CMAltimeter — materially more accurate than GPS altitude. |
| 15-second autosave | **Must** | Bounds worst-case loss; non-negotiable for trust. |
| Ride mode screen | **Must** | Artboard F: huge numerals, near-black, minimal lit pixels. |
| Live Activity | Should | Running ride visible on the lock screen; tap to log. |
| Manual ride start/stop | **Must** | The reliable path; automatic detection is unproven. |
| Automatic ride detection | Nice | Motion-triggered start/stop, only if it proves trustworthy. |
| Auto-pause at stops | Should | Separates moving time from elapsed time honestly. |

### Epic C — Money
| Feature | Priority | Description |
|---|---|---|
| Expense model, local-only | **Must** | Integer paise, never Double; `.localOnly` at model level. |
| Ride-expense fusion | **Must** | Expenses inside a ride window attach automatically, reversibly. |
| Per-trip true cost | **Must** | Total spend surfaced on the ride detail view. |
| Fuel economy calculation | **Must** | km/L between consecutive full-tank fills. |
| Category breakdown | Should | Fuel vs. food vs. parts vs. tolls over a period. |
| Expense editing and reassignment | Should | Fusion must be correctable, not authoritative. |

### Epic D — Bike operations
| Feature | Priority | Description |
|---|---|---|
| Service tasks with km/date intervals | **Must** | Chain lube, oil, pads, tyres, custom. |
| Computed due state | **Must** | Derived from current odometer; never stored. |
| Service event history | **Must** | What was done, when, at what odometer, at what cost. |
| Document expiry tracking | **Must** | Insurance, PUC, RC, DL with dates and identifiers. |
| Local notifications | **Must** | Configurable lead times; no push entitlement needed. |
| Odometer management | **Must** | Manual entry plus GPS-derived suggestions. |
| Document attachments | Should | Store a photo or PDF locally against each document. |

### Epic E — Review and insight
| Feature | Priority | Description |
|---|---|---|
| Today screen | **Must** | Artboard E: live ride, recent entries, due items, week strip. |
| Ride history list | **Must** | Chronological, searchable by place and date. |
| Map replay with elevation | **Must** | Polyline plus elevation profile; degrades gracefully offline. |
| Trend charts | **Must** | Distance, spend and km/L over time via Swift Charts. |
| Weekly auto-summary | **Must** | Generated, not requested. |
| Per-trip recap | Should | Shareable-looking recap card, local-only until v2. |
| Data export (CSV/JSON) | Nice | v1.5; useful, not load-bearing. |

### Epic F — Foundation
| Feature | Priority | Description |
|---|---|---|
| Sync-ready data model | **Must** | UUIDs, ownerID, timestamps, soft deletes, syncScope on every model. |
| CurrentUser abstraction | **Must** | Local stub in v1, real account in v2, zero call-site changes. |
| Multi-vehicle support | **Must** | Model and picker; cheap now, a migration later. |
| Design token system | **Must** | One generated Swift file; no hardcoded hex in views. |
| Onboarding | Should | Three screens: add bike, set odometer, grant location. |
| Settings | Should | Units, currency, notification lead times, vehicle management. |

---

## 8. Dependencies

### External APIs and services
- **Apple frameworks (hard dependency):** SwiftUI, SwiftData, CoreLocation,
  CoreMotion, MapKit, Swift Charts, ActivityKit, App Intents, UserNotifications.
  All first-party, all free, no API keys, no rate limits.
- **No third-party APIs in v1.** No geocoding service, no weather, no fuel-price feed.
  Each would add a network dependency to an offline-first product.
- **MapKit basemap tiles** require network on first view of a region. There is no
  sanctioned offline cache. Mitigation: render the route polyline on a plain canvas
  with no basemap when offline; revisit MapLibre + MBTiles only if offline replay
  proves genuinely necessary on long rides.
- **Apple Developer Program ($99/yr)** — hard blocker for all of v2.

### Team and resource dependencies
- Single developer, part-time, against coursework. This is the binding constraint on
  everything in this document.
- Physical dependency: an actual motorcycle and real rides for testing. Simulator
  testing cannot validate GPS drift, battery drain or gloved usability — the three
  riskiest areas.
- A Mac with Xcode, required every 7 days for re-signing.
- 3–5 riding friends willing to trial at v2.

### Third-party risks
| Risk | Severity | Mitigation |
|---|---|---|
| App Groups unavailable on free signing | Medium | Spike week 1; Action Button path is unaffected; defer widgets. |
| SwiftData migration bugs on schema change | High | Freeze schema before real data lands; export/reimport escape hatch. |
| iOS suspends background location under pressure | High | 15s autosave; treat suspension as expected, not exceptional. |
| MapKit offline degradation looks broken to users | Low | Design the no-basemap state deliberately, not as an error. |
| 7-day re-sign friction kills the habit | **High** | Honest watch item; may force the $99 purchase earlier than planned. |
| Apple deprecates or changes Action Button APIs | Low | First-party, recent, unlikely; Shortcuts fallback exists. |

---

## 9. Stakeholders

### Owner
**Arnav Parmaj** — product owner, designer, sole engineer, and primary user. Holds
final say on every decision in this document. The unusual property of this project is
that the owner and the user are the same person, which removes discovery risk and
replaces it with objectivity risk: there is nobody to say the idea is wrong.

### Must be consulted
- **The riding friends earmarked for the v2 trial (3–5 people).** Consulted before any
  sharing feature is designed — specifically on whether they would tolerate weekly
  re-signing, and what they would expect to see of each other's data.
- **A mechanic or experienced rider**, on realistic service intervals per model.
  Wrong intervals make the ops pillar actively harmful advice.
- **Claude Code**, as implementation partner, bound by `CLAUDE.md`; expected to raise
  objections rather than silently implement questionable instructions.

### Must be informed
- Nobody externally, while the app is personal. There is no organisation to report to,
  and inventing one would be ceremony.
- At public release: Apple App Review, and users via a privacy policy that states
  plainly that expense data never leaves the device.

---

## 10. Open Questions

Each must be answered before or during the build phase indicated.

| # | Question | Needed by | Why it blocks |
|---|---|---|---|
| 1 | Are App Groups available under free provisioning? | Week 1 | Determines whether any widget or Control Center work is possible at all. |
| 2 | What is the app actually called? "TRACE" is a placeholder. | Before first build | Bundle ID, app name and the design wordmark all bake it in. |
| 3 | Is a ride started manually, or auto-detected by motion? | Before Epic B | Changes the recording state machine and the entire Ride mode entry path. |
| 4 | What exactly ends a ride — a stop duration threshold, manual stop, or geofence? | Before Epic B | Determines the fusion time window, which the core differentiator depends on. |
| 5 | Is the odometer authoritative (manual) or derived (GPS-summed)? | Before Epic D | Service intervals read from it; GPS drift would make them wrong over months. |
| 6 | What is the RouteSample retention policy? | Before first real data | The only unbounded table; retrofitting deletion to synced data is painful. |
| 7 | When is the $99 bought — on a date, or triggered by the friend trial? | Week 3 | Gates all of v2 and may be forced early by re-signing friction. |
| 8 | Does v1 ship multi-vehicle UI, or just the data model? | Before Epic F | Model is cheap; the picker UI costs real screens. |
| 9 | How are partial fuel fills handled in km/L? | Before Epic C | Mishandling silently corrupts the one metric riders actually check. |
| 10 | What happens to a ride in progress when the app is force-killed? | Before Epic B | Determines recovery UX; silent loss is the trust-destroying failure. |
| 11 | Is there a revenue model if this goes public? | Before v3 | Free with no server is sustainable; paid implies support obligations. |
| 12 | Do friends see each other's routes by default, or opt-in per ride? | Before v2 | Was answered loosely as "everything except money" — needs a precise default. |
