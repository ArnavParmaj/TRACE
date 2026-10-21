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
