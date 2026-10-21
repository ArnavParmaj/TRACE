# CLAUDE.md — TRACE

New here? Read `CONTEXT.md` first — one file, the whole picture.
Then `docs/INDEX.md`, which lists every document and where new ones go.
The specs are `docs/product/PRD.md`, `docs/product/SCOPE.md`,
`docs/engineering/DATA-MODEL.md`, `docs/engineering/ARCHITECTURE.md` and
`design/DESIGN.md`. This file is the short list of things that must not be got wrong.

Returning session? Do not re-read everything. Read `CONTEXT.md` § "Where things stand",
the first milestone not marked DONE in `docs/product/ROADMAP.md`, and
`git log --oneline -10`. Open other docs only when the task touches them.

## What this is
An offline-first iOS motorcycle logger. Three pillars: **route**, **money**,
**bike ops** (service + documents). SwiftUI + SwiftData, iOS 18+, iPhone 16.
No backend. Single user today, multi-tenant product later.

Launched on a **free Apple developer account**: no push, no iCloud/CloudKit,
no HomeKit, 7-day re-sign. App Groups DO work (decision 39). Never propose a solution that
needs a paid entitlement without saying so out loud.

## Invariants — do not violate these without asking

1. **Money never leaves the device.** `Expense` is `syncScope = .localOnly`,
   enforced at the model level. No sync, export-to-friends, or analytics path may
   read it — now or in v2. This is a product promise, not a preference.
2. **Money is `Int` minor units (paise).** Never `Double`, never `Float`,
   never `NSDecimalNumber` in the store. Format only at the view layer.
3. **Every model carries all five sync fields**: `id: UUID`, `ownerID: UUID`,
   `createdAt`, `updatedAt`, `deletedAt: Date?`, plus `syncScope`.
   No autoincrement integer IDs anywhere — they collide when devices merge.
4. **Every repository query is scoped by `CurrentUser.ownerID`.** Never query a
   model type directly from a view. The stub is single-user; the call sites must
   not know that.
5. **Deletes are soft.** Tombstones are what sync reconciles against.
6. **Service due state is computed, never stored.** Stored due dates go stale.
7. **Capture never blocks.** The Action Button intent writes a `CaptureDraft` and
   returns. If completing an entry needs UI, that happens later, in the app.
8. **Ground is `#000000`.** Not `#0A0A0A`, not "near black". OLED pixels must be off.
9. **Red (`--alarm`) is reserved** for overdue / expired / urgent. Never decorative.
   Red text uses `--alarm-ink` (`#E0241B` fails contrast as small text on black).
10. **Touch targets >= 60pt**, not 44. The user is wearing gloves.

## Style
- Swift 6 concurrency. `@Observable` services, not ObservableObject.
- No third-party dependencies without asking. SwiftData, MapKit, Swift Charts,
  ActivityKit, CoreLocation, CoreMotion and UserNotifications cover v1.
- Design tokens live in one hand-written Swift file, `TRACE/Design/Tokens.swift`;
  `TokenTests` fails if it drifts from `design/DESIGN.md` (decision 41).
  Never hardcode a hex in a view.
- Keep views dumb. Logic belongs in services, data access in repositories.

## Build order (from engineering/ARCHITECTURE.md)
Models/repos → ride recording → Today screen → capture intent → expenses + fusion
rule → service → documents → ride mode → replay/charts → summaries.

Ride recording comes first deliberately: background location is the only part that
can genuinely surprise us. Everything else is CRUD.

## Open items — raise these, do not silently decide them
- Widget / Control Center control: technically unblocked (decision 39) but not in v1
  scope. Scheduling either is a scope decision; ask first.
- App name. "TRACE" is a placeholder.
- v1.5+ features (segments, gear log) are out of scope — do not build ahead.

## Working agreement
- Update `docs/DECISIONS.md` whenever a real decision is made. Append a numbered
  row with the rationale, never rewrite history.
- Every new document goes in the right folder per `docs/INDEX.md`, and is added to
  that index in the same change.
- If a doc and the code disagree, the doc is stale — fix the doc in the same change.
- Push back when something looks wrong. Say so plainly rather than building it.
- At every checkpoint, update `CONTEXT.md` § "Where things stand" and mark the milestone
  DONE in `ROADMAP.md`, in the same commit. That is what the next session reads first.
