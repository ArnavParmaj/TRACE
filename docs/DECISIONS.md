# Decision log

| # | Date | Decision | Rationale |
|---|------|----------|-----------|
| 1 | 2026-10-21 | SwiftUI native, not React Native | deep iOS hooks (Action Button, Live Activity, Control Center) are the product, not a nice-to-have |
| 2 | 2026-10-21 | Free dev account, no backend | forces offline-local, which the product wants anyway |
| 3 | 2026-10-21 | Dark-only theme | night riding, handlebar mount, OLED battery |
| 4 | 2026-10-21 | Design language shortlist narrowed to 7, 4 hybrids queued | all picks share flat/print/instrument DNA |
| 5 | 2026-10-21 | Vehicle = motorcycle | confirmed by user; unlocks km/L, service intervals, glove targets, mount layout |
| 6 | 2026-10-21 | "Strava for motorcycles" is a capture-quality benchmark, not a feature spec | no social, no server, no accounts; money + time logging stay first-class |
| 7 | 2026-10-21 | Study-time pillar removed | app is motorcycle-first; third pillar is bike ops |
| 8 | 2026-10-21 | Solo v1, friends deferred to v2 | free signing can't distribute; defers server, $99 and leaderboards together |
| 9 | 2026-10-21 | Money never syncs, ever | spends stay on-device even once sharing exists |
| 10 | 2026-10-21 | v1 ops = maintenance + documents; motion metrics deferred | both are arithmetic/dates and cheap; CoreMotion is a new subsystem with worst battery cost |
| 11 | 2026-10-21 | Multi-tenant product, not personal app + sharing | public release is real future scope; friends are full users with own accounts |
| 12 | 2026-10-21 | Money is permanently local — never syncs, even in public version | only pillar with a hard wall; decided before any sync code exists |
| 13 | 2026-10-21 | v1 built sync-ready: UUIDs, ownerID, timestamps, soft deletes, CurrentUser abstraction | costs ~nothing now, is a data-layer rewrite later |
| 14 | 2026-10-21 | Sign in with Apple when auth arrives, never hand-rolled credentials | App Store requirement alongside third-party login; avoids owning a security surface |
| 15 | 2026-10-21 | Design frozen: OLED Splice (Hybrid B structure + D typography, true black) | pure D spends red on decoration, leaving no alarm colour for overdue/expired states; filled colour fields also cost battery while riding |
| 16 | 2026-10-21 | Agit-Print character carried by unlit elements only | hairline diagonals, numbered chips, stencil slugs — identity at zero pixel cost |
| 17 | 2026-10-21 | Money stored as integer minor units (paise) | Double currency does not reconcile |
| 18 | 2026-10-21 | Service due state computed, never stored | stored due-dates go stale silently |
| 19 | 2026-10-21 | App Groups availability on free signing is an open RISK, spiked in week 1 | may block widget/Control Center extensions until $99; Action Button path is unaffected |
| 20 | 2026-10-21 | Docs reorganised into product/ engineering/ design-notes/ with an INDEX.md | more documents are coming; a flat docs/ stops being navigable fast |
| 21 | 2026-10-21 | PRD rejects DAU/NPS-style KPIs for v1 | meaningless at n=1; v1 success is "does the author stop hand-logging", measured by capture rate and week-8 retention |
| 22 | 2026-10-21 | Ride start is MANUAL in v1 | auto-detect misfires create phantom rides; one phantom ride destroys trust in the log |
| 23 | 2026-10-21 | Ride ends on manual stop, with a 10-minute-stationary auto-close fallback | bounds the damage of a forgotten stop without inventing rides |
| 24 | 2026-10-21 | Odometer is manual and authoritative; GPS only suggests | GPS sums drift 2-5%, which would put service intervals hundreds of km wrong within a year |
| 25 | 2026-10-21 | Force-kill recovery: on launch, detect an open ride and offer resume or close-at-last-autosave | silent discard is the one unrecoverable trust failure |
| 26 | 2026-10-21 | km/L computed only between consecutive full-tank fills; partials logged but excluded and flagged | partial fills silently corrupt the one number riders check |
| 27 | 2026-10-21 | RouteSample retention: raw for 90 days, then downsampled to 5s intervals | only unbounded table; policy decided before real data lands, not after |
| 28 | 2026-10-21 | Multi-vehicle: data model in v1, picker in Settings, no switcher UI | model is cheap, screens are not |
| 29 | 2026-10-21 | No auto-pause. Stops over 120s count as stopped-time; everything else is moving-time | auto-pause at ~3 km/h produces hundreds of events per Mumbai commute and garbage data |
| 30 | 2026-10-21 | Stop classification (toll/signal/fuel detection) deferred to v1.5; v1 records raw StopEvents only | thresholds are unguessable from an armchair and must be tuned on 4-6 weeks of real routes |
| 31 | 2026-10-21 | XcodeGen + project.yml instead of a checked-in .xcodeproj | .xcodeproj is unmergeable binary-ish XML an agent edits badly; project.yml is text |
| 32 | 2026-10-21 | Navigation: custom 4-tab bar (Today / Rides / Money / Bike), ≥60pt tall | one tab per pillar plus the hub; stock tab bar is 49pt, under the glove rule |
| 33 | 2026-10-21 | Action Button always writes a CaptureDraft, ride or no ride; rides start only from the app | one predictable behaviour with gloves on; state-dependent press risks phantom rides (decision 22) |
| 34 | 2026-10-21 | Ride mode is portrait only | matches Info.plist and common mounts; one layout to test on the most safety-critical screen |
| 35 | 2026-10-21 | Roadmap gated by exit criteria, not dates; 8-week dogfood gate before any v1.5 work | the failure mode is an unused app, and features do not fix a habit that did not form |
| 36 | 2026-10-21 | Capture button spine is amber, not red (DESIGN.md amended) | red is reserved for overdue/expired/urgent; a red spine on the most-used control taught the eye to ignore red |
| 37 | 2026-10-21 | Expense categories: Fuel, Food, Parts, Parking, Other. Tolls out of scope | most Indian highways don't toll motorcycles; tolls can land in Other until data says otherwise |
| 38 | 2026-10-21 | Motion is functional only: press feedback, system sheets/pushes, capture confirm, hold-to-stop. No loops, no stagger, no translucent materials | rider's eyes belong on the road; every animated or blurred pixel is lit on OLED |
| 39 | 2026-10-21 | App Groups work on the free Personal Team (spike passed); widget/Control Center are unblocked but not scheduled for v1 | spike: app + widget extension both signed with group.com.arnavparmaj.trace, app got a real shared container on the iPhone 16; spike target removed |
| 40 | 2026-10-21 | No `.unique` on ids; every model property defaulted or optional; two stores (synced / local-only) | CloudKit-backed SwiftData rejects unique constraints and needs defaults, so v2 sync needs no migration; the local store never gets CloudKit, so money stays on-device by construction |
| 41 | 2026-10-21 | Design tokens hand-written in Tokens.swift, verified against DESIGN.md by a test | a generator for 12 colours is more code than the colours; the test catches drift |
| 42 | 2026-10-21 | One generic `Repository<T: SyncRecord>` instead of a protocol per model | owner scoping and soft delete written once; tests use an in-memory container, so no mock protocols are needed |
| 43 | 2026-10-21 | graphify knowledge graph set up in the repo (CLAUDE.md section, Claude hooks, git hooks); graphify-out/ is gitignored | sessions query the graph instead of re-reading files; the graph is rebuilt by hooks after every commit, so committing it would dirty the tree each time |
| 44 | 2026-10-23 | App icon is concept A "Route": an amber ride line with a start ring and finish dot on true black; default, dark and tinted 1024px PNGs drawn by `design/icon/render.swift` | a route mark survives the placeholder name changing, where a "T" monogram would not; CoreGraphics script means no SVG tool dependency and the PNGs are reproducible. Concepts: https://claude.ai/artifact/Hh8eidwrmvYjq4qL3qwjdN |
| 45 | 2026-10-23 | Recorder runs GPS at 1 Hz best accuracy in foreground and background; accuracy tiering deferred | tiering is a battery optimisation with no measured need yet; a distance filter would also stop fixes while parked, which the stop and auto-close timing rely on. Revisit if the M2 ride measures drain above ~8%/h |
| 46 | 2026-10-23 | Stationary means speed < 1 m/s; fixes worse than ±30 m are stored but not counted; distance only accumulates while moving | parked GPS jitter otherwise adds phantom km; raw samples keep everything for later re-processing |
| 47 | 2026-10-23 | Autosave every 15s timed off fix timestamps, plus an immediate save when the app backgrounds | a timer does not fire reliably in the background, fixes do; a swipe-kill always follows backgrounding, so that save makes the usual kill lose ~0s |
| 48 | 2026-10-23 | Route stored as a Google encoded polyline of moving fixes | standard, compact (~6 bytes/point), and every map tool reads it; no format of our own to maintain |
| 49 | 2026-10-23 | Until bike onboarding (M5), rides log against `UUID.unowned` as vehicle | M2 needs rides, not bikes; M5 assigns existing rides to the first bike |
| 50 | 2026-10-23 | Supersedes 23: auto-close after **30 minutes** stationary, and stationary also means staying within **50 m** of where the still spell began; drifting further restarts the clock | Mumbai gridlock and level crossings hold a bike dead still for 10+ minutes mid-trip, and speed reads under 1 m/s while creeping; 30 min still bounds a forgotten stop. The 50 m reset also splits stop events, so creep counts as moving time, not a stop |
| 51 | 2026-10-23 | Manual pause: GPS and barometer off, ride stays open. Paused time is neither moving time nor a stop; distance is not bridged across a pause; Stop while paused ends the ride at the pause; a pause survives a kill (`Ride.pausedAt`) | the rider asked for pause distinct from stop. GPS off saves battery during long breaks; ending at the pause keeps a forgotten pause from inflating the ride. Not auto-pause, so decision 29 stands |
| 52 | 2026-10-23 | Haptics on every interaction: light tap on touch-down for every button and tab; success on ride start / resume / stop; heavy tap on pause; warning on destructive confirm. One haptic per press. Replaces SCREENS rule 9 ("nothing else buzzes") | with gloves on, a felt press is the only confirmation the touch registered; distinct pause vs stop feel prevents mistaking one for the other |
| 53 | 2026-10-23 | A plain read-only ride list on the RIDES tab during M2 (date, km, total, moving, avg and max km/h); no tap-through | a recorded ride was invisible without it, so the M2 ride test needed a database pull to check. M7 replaces it with S06 as planned; not building ahead, no map or detail |
| 54 | 2026-10-23 | Commits and PRs carry no AI attribution: no `Co-Authored-By` trailer, no "Generated with Claude Code" line, Claude not listed as collaborator | the author chose this for the repo; CLAUDE.md overrides default tool attribution, which would otherwise win on every commit |
| 55 | 2026-10-23 | **M2 passed.** Real ride: 78 min, 31 km, force-kill recovered with ≤6 s lost. Battery drain **6.9%/h** (68% → 59%; Bluetooth music for half the ride; battery health 88%, ≈6.1%/h on a new battery). Accuracy tiering stays off | under the ~8%/h threshold set in decision 45, so tiering would add code and risk for no felt gain. Re-measure if a future ride with screen-on Ride mode (M6) goes above it |
| 56 | 2026-10-23 | Added to plan: route line coloured by speed on ride detail (M7, S07); trip meters A and B on the Bike tab (M5, S11), computed from rides since each reset. Ghat / section timing stays in v1.5 "Segments and personal bests" | asked for after the first real ride. Speed colour needs no new data (samples carry speed); trip meters store only a reset time, so they cannot go stale. Section timing needs route matching, which is v1.5 scope by the CLAUDE.md rule |
