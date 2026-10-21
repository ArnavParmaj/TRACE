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
iCloud/CloudKit, no HomeKit, App Groups availability unverified, re-sign from Xcode
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

Design frozen. Specs written. **No code yet.** The next milestone is not a document —
it is a ride recorded on a real road and still present after a force-kill.

Build order puts ride recording first, deliberately. Everything else in v1 is CRUD,
and CRUD does not surprise anyone at 2am; background location does.

## Known risks, named honestly

- **The author stops using it within three weeks.** Most likely failure mode. No
  amount of code quality compensates. Success is measured by capture rate and week-8
  retention, not by shipped features.
- **App Groups may be unavailable** on free signing, blocking widget and Control
  Centre work. Spike it in week 1. The Action Button path is unaffected either way.
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
docs/DECISIONS.md                numbered, append-only decision log (31 entries)
docs/product/PRD.md              full product requirements
docs/product/SCOPE.md            pillars, phasing, privacy rule
docs/engineering/ARCHITECTURE.md layers, capture path, GPS strategy, risks
docs/engineering/DATA-MODEL.md   entities, sync fields, fusion rule
docs/engineering/BUILD-PLAN.md   week 1, task by task, with checkpoints
```

Start with `CLAUDE.md`, then `docs/engineering/BUILD-PLAN.md`. Everything else is
reference you read when the task touches it.

## Still unanswered

- The app's actual name. "TRACE" is a placeholder; the bundle id is changeable.
- App Groups on free provisioning (spike pending).
- Whether $99 gets bought on a date or when the friend trial demands it.
