# Build plan — week 1

Goal of week 1 is one thing: **a ride recorded on a real road, saved, and still there
after a force-kill.** Not a pretty app. Not a complete app. A trustworthy recorder.

Everything else in v1 is CRUD, and CRUD does not surprise anyone.

## Day 0 — scaffold (2 hours)
1. `brew install xcodegen`
2. `project.yml` defining target TRACE, iOS 18 deployment, bundle id
   `com.arnavparmaj.trace`, Info.plist keys:
   - `NSLocationWhenInUseUsageDescription`
   - `NSLocationAlwaysAndWhenInUseUsageDescription`
   - `NSMotionUsageDescription`
   - `UIBackgroundModes: [location]`
3. `xcodegen generate`, open, build, run empty app on device.
4. `git init`, first commit.

**Checkpoint:** empty app launches on the actual iPhone 16. Stop if it does not.

## Day 0.5 — the App Groups spike (1 hour, do it before anything else)
Create a throwaway widget extension target with an App Group capability. Try to build
and sign it with the free account.

- **Works** → widgets and Control Center controls are available later. Note it.
- **Fails** → record the exact error in DECISIONS, delete the target, build nothing
  that depends on a shared container until the $99 is bought.

Either way the Action Button path is unaffected. Do not let this block the week.

## Day 1-2 — models and repositories
- All entities from `DATA-MODEL.md` with the five universal fields.
- `SyncScope` enum; `Expense` hardcoded `.localOnly`.
- `CurrentUser` protocol + `LocalStubUser`.
- Generic `Repository<T>`, every query scoped by `ownerID` (decision 42).
- Design tokens in one hand-written Swift file, checked against `design/DESIGN.md` by a test.
- Unit tests on: soft delete excluded from queries, ownerID scoping, money arithmetic
  in integer paise.

**Checkpoint:** tests green. No UI yet.

## Day 3-5 — the recorder (the hard part)
- `LocationService`: CoreLocation, `allowsBackgroundLocationUpdates = true`,
  `activityType = .otherNavigation`, accuracy tiering by foreground state.
- `RideRecorder`: start, stop, 15s autosave, open-ride recovery on launch.
- `CMAltimeter` for barometric climb.
- `StopEvent` recorded raw (dwell > 120s), unclassified — per decision 30.
- Polyline encoding on ride close.

**Checkpoint, and this is the real one:** ride to Lonavala or anywhere over an hour.
Force-kill the app mid-ride. Reopen. The ride must be recoverable with no more than
15 seconds missing. Measure battery drain per hour and write the number down.

If this checkpoint fails, nothing else matters. Fix it before moving on.

## Day 6-7 — Today screen + capture
- Today screen per artboard E.
- App Intent `LogEntryIntent` writing a `CaptureDraft`, bound to the Action Button.
- Draft completion sheet.

**Checkpoint:** log a real fuel fill at a real pump, wearing gloves, without unlocking.

## Not in week 1
Expenses UI beyond drafts, fusion rule, service, documents, ride mode, map replay,
charts, summaries. All of it waits. Week 2 is for the rest of v1.

## Standing rules during build
- Commit per checkpoint, not per file.
- Append to `docs/DECISIONS.md` whenever something real is decided.
- When a doc and the code disagree, fix the doc in the same commit.
- Do not build ahead of the plan. Scope creep before a shipped v1 is the documented
  failure mode for this project.
