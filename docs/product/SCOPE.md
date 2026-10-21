# Scope

## Pillars (study time removed 2026-10-21)
1. **Route** — ride capture, replay, stats. The spine.
2. **Money** — fuel, tolls, chai, parts. Fuses into the ride that contained it.
3. **Motorcycle ops** — four candidates, phased below.

## Phasing

### v1 — solo, offline, free signing, 2-3 weeks
- One-tap capture: Action Button, Live Activity; Control Center tile only if the
  App Groups spike allows it
- Ride recording: GPS route, distance, duration, speed, barometric climb
- Ride replay: MapKit polyline, elevation profile, splits
- Money entries, auto-absorbed by the ride whose time window contains them
- **Maintenance & service**: due-at-km off the odo (chain lube, oil, pads, tyres).
  Cheap — it is arithmetic on a number already tracked. Local notifications work
  on free signing (no push entitlement needed).
- **Documents & expiry**: insurance, PUC, RC, DL. Date fields plus local
  notifications. Near-zero cost, high real-world value, nothing decent exists in India.
- Weekly + per-trip auto summary
- Swift Charts trends

### v1.5 — once v1 is in daily use
- **Gear & mods log**: parts fitted, cost, helmet age. Plain CRUD, no new tech.
- **Segments + personal bests**: named stretches, your own PB over time.
  Purely local — no server. Cost is the route-matching algorithm, not infra.

### v2 — needs $99 account
- TestFlight distribution to friends (the only sane way; free signing dies in 7 days)
- CloudKit sync (free with the paid account, no Supabase needed)
- Leaderboards vs friends
- Ride feed / post a ride

### Deferred, possibly never
- **Ride quality metrics** (CoreMotion lean angle, braking events, vibration).
  Highest cost, least proven value, worst battery. Revisit only if v1 sticks.

## Product shape
This is a multi-tenant product that launches with one user, NOT a personal app with
sharing bolted on. Public release is real future scope, blocked today only by the
$99 account. Every friend is a full user with their own account and their own data;
"close friends get everything" means full feature access, not visibility into each
other's records.

## Privacy rule (fixed)
- **Money never leaves the device. No sync, no sharing, no exceptions** — including
  in the public version. It is the one permanently local pillar.
- Rides and ops data are shareable once sharing exists, per the owner's choice.
- Home start/end fuzzing: deferred to v2, when routes can actually leave the phone.

## Foundation decisions (v1 must honour these even while fully offline)
- Every record carries a UUID primary key, an `ownerID`, `createdAt`, `updatedAt`
  and a soft-delete flag. Sync needs all five; retrofitting them is a rewrite.
- A `CurrentUser` abstraction sits in front of all queries. v1 fills it with a local
  stub user; v2 swaps in a real account with no call-site changes.
- No integer autoincrement IDs anywhere — they collide the moment two devices merge.
- Money entities are marked local-only at the model level, so no future sync pass can
  accidentally pick them up.
- Auth, when it arrives: **Sign in with Apple**. Not hand-rolled id/password —
  it is mandatory on the App Store alongside any third-party login anyway.

## Public-release checklist (v3, for awareness only)
$99 account · privacy policy (required: location + health-adjacent data) ·
App Review justification for background location · App Store screenshots ·
data-deletion path (legal requirement once accounts exist).

## Why this cut
Four pillars x four social features is a semester, not three weeks. v1 keeps the two
ops features that are arithmetic-and-dates (maintenance, documents) and drops the two
that are new subsystems (motion sensing, social sync). Nothing here blocks the rest
later — the data model below is written with all of it in mind.
