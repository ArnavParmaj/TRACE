# TRACE

Offline-first iOS ride logger for motorcycles. Route, money, and bike ops. SwiftUI, on-device only.

Status: **pre-development — design language not yet chosen.**

## What it is
One-tap capture (Action Button / Control Center / Live Activity) that logs a ride,
a spend or a maintenance event without unlocking the phone. GPS route, climb, speed and
timestamp are captured automatically; you confirm the amount or label later.

The differentiator: a ride session auto-absorbs the spends that happened inside its
window, producing one fused trip object, and the same odo feeds service intervals.
Route apps, expense apps and maintenance apps each own one slice; nothing joins them.

Shorthand: "Strava for motorcycles" — for capture and replay quality only. No social
graph in v1. See docs/SCOPE.md.

## Constraints (fixed)
- Target: iPhone 16 (non-Pro), iOS. Personal use, not App Store.
- Stack: SwiftUI + SwiftData. No backend, no accounts, no network dependency.
- Signing: free Apple developer account — 7-day re-sign, 3-app limit,
  no push / iCloud / HomeKit entitlements. Offline-local is therefore mandatory,
  which matches the product goal anyway.
- Scope: 2-3 week build.
- Theme: dark only.
- Vehicle: **motorcycle** (confirmed 2026-10-21). Implies km/L fuel math,
  service-interval tracking, glove-sized tap targets (>=60pt), handlebar-mount
  landscape view, CoreMotion lean/vibration available as a later signal.

## Positioning
Closest shorthand is "Strava for motorcycles", but only for the route-and-stats
half. The differences are deliberate and load-bearing:
- No social graph, no leaderboards, no segments, no kudos. Single user, no accounts.
- No server. Nothing leaves the phone. (Also forced by free-tier signing.)
- Money and study-time logging are first-class, not bolted on — the fusion of
  route + spend + time is the actual product.
Treat Strava as the reference for *ride capture and replay quality only*.

## Open decisions
- [ ] Design language — 4 hybrid directions to mock up, then choose against the
      7 shortlisted standalones. See `design/DESIGN.md`.
- [ ] App name — TRACE is a placeholder.

## Layout
- `docs/` — scope, specs, data model, architecture, decision log
- `design/` — design language exploration and chosen tokens
