# Current and past issues

A running log of what broke, what was tried, and how it ended. New sessions: read the
**Open** section first. When an issue is fixed, move it to **Resolved** and write what broke,
the cause, the fix, and how it was checked. Never delete a row. Decisions live in
`../DECISIONS.md`; this file is the trail that led to them.

Status key: OPEN, MONITORING (fix in, needs a phone check), FIXED, WONTFIX.

## Open

### I-01 Accessibility audit: Dynamic Type "partially unsupported" (OPEN)
- **Where:** `TRACEUITests/AccessibilityAuditTests.swift`, `testEveryTabPassesAudit`. About 17 findings on RIDES and BIKE: PB card values and labels, `OCT 23`, `PB`, `HOLD TO RESET`; "potentially inaccessible text" on RIDES.
- **Tried, all reverted (no effect):** changing `relativeTo` on `Font.oswald`; `@ScaledMetric` for tracking; removing tracking on the four labels (the look changed, the finding stayed); Accessibility Inspector on the phone (31 similar warnings, cause not shown).
- **State:** cause not found. Decision 73 records the exceptions as open and not silenced; the audit test is left failing on purpose.
- **Next:** M8 step 4 (check the largest Dynamic Type size by eye on the phone); decide whether the audit exceptions are real or an audit artefact.

### I-02 Simulator timing: 200 km ride detail over 2 s (OPEN)
- **Where:** `TRACEUITests/ReplayTimingTests.swift`, `testLongRideOpensUnderTwoSeconds`. Seeded ride "TEST 200 KM" (10,000 samples, `-seedLongRide`).
- **Measured (iPhone 17, iOS 27 simulator, repeated 4 runs):** map 2.1 to 2.2 s, elevation 3.2 to 3.3 s from tap. Includes XCUITest query overhead; the Mac is faster than the phone, so the phone will not be quicker.
- **Suspect:** `RideSheet.loadReview()` fetches the samples and builds the analysis on the main thread.
- **Next:** profile the open, move the analysis off the main thread if that is the cost; re-measure on the simulator and the phone (M7 exit: under 2 s).

### I-03 Cold open to last trip cost (MONITORING: simulator passes at 8.2 s)
- The 8.2 s includes about 6 s of XCUITest launch overhead, so the app itself is well under 10 s on the simulator. Phone timing still to do.
- Earlier failures were the test's data, not the app, see R-08.

### I-04 Close buttons are not in one place (FIXED in code, check on phone)
- Every sheet now has CLOSE top-right. `SheetBar` already did this; `ExpenseSheet` was the one screen with CLOSE top-left. It now matches, with DELETE / DISCARD DRAFT moved to the far left so a gloved miss next to CLOSE cannot discard a draft.
- Left as is: ride mode's `‹` (top-left, back to Today while the ride keeps recording) and onboarding's `‹ BACK` (previous step). Both are "back", not "close".

### I-07 Design critique 2026-10-29: 28 items (OPEN, 6 major fixed in code)
- Full list: `design-critique-2026-10-29.md` (score 25/40). Rider's order: 6 major, then the undo bar everywhere, then items 7–22; polish 23–28 later.
- Fixed in code, check on the phone (MONITORING):
  - 1 Location denied: Today shows LOCATION IS OFF · SETTINGS › instead of START RIDE; ride mode says LOCATION OFF; onboarding shows ALLOWED / SETTINGS › from iOS's real answer.
  - 2 Today's ride clock ticks every second and leaves pauses out (`RideRecorder.elapsed(at:)`, shared with ride mode).
  - 3 DISCARD DRAFT shows a 5 s UNDO bar (decision 78).
  - 4 Today's DUE rows open the task or document.
  - 5 Picking a prefilled number field (edit expense, mark service done) dims it; the first key replaces it.
  - 6 Money ‹ › steps through past periods (decision 77).
- Checked: 73 unit tests pass (new: elapsed, undo restore, keypad replace, Money period). Simulator: DUE row opened PUC; Money stepped back to SEPTEMBER. The undo bar itself is not yet seen on screen.
- Also found by the UI audit: the onboarding REGISTRATION field may clip at large text sizes (joins I-01).
- Known gaps: location turned off mid-ride has no Settings link (ride mode only says LOCATION OFF); on a
  field the first key replaces, ⌫ clears the whole value, not one digit.

### I-05 Phone checks not yet done (OPEN)
- M3 real fuel pump (user expects it to work, no result yet), M4 km/L by hand on the phone, M6 handlebar mount (no mount yet), M7 timings and airplane-mode replay on the phone, PB badge and keypad check on the phone, M8 step 6 tap-through offline.
- M5 notification: the user reports it worked.

### I-06 Free-signing 7-day expiry (RECURRING)
- Every ~7 days the app shows "no longer available". Fix: rebuild and reinstall over the top. Never uninstall, that deletes the ride data.

## Resolved

### R-01 Expense draft: keypad stacked with the system keyboard (FIXED)
- **Broke:** the numeric keypad stayed on screen while typing the optional note, so both keyboards covered the form.
- **Cause:** the keypad was always shown once a category was picked.
- **Fix:** `ExpenseSheet.swift` keeps `keypadOpen` (false by default); tapping an amount opens it, a DONE button above it closes it, and focusing the note field hides it. Covered by `testKeypadOpensOnAmountAndHidesForNote`.

### R-02 PB badge showed an old run after a new personal best (FIXED, decisions 75 and 76)
- **Broke:** the PB card still showed the previous day's run after a better one.
- **Cause:** confusion over which record each badge meant; badges also cluttered the Rides list.
- **Fix:** `Review.PersonalBests.records(for:)` names the records a ride holds (LONGEST, TOP SPEED, CLIMB, 10 KM); the badge moved into the ride detail sheet (`RideSheet`) and was removed from the list. Test `recordsNameOnlyTheBestsARideStillHolds`.

### R-03 Climb figure looked too high (FIXED, decision 74)
- **Broke:** an earlier note said the barometer climb "reads high".
- **Check:** the user gave start/mid/stop/end points of the same route; elevation from the Open-Meteo API was compared with the logged climb.
- **Result:** the barometer stands; the "reads high" claim was wrong and is corrected in decision 74.

### R-04 Audit: contrast and clipping findings (FIXED, partly)
- **Broke:** small text in `inkFaint` failed contrast; some labels clipped at large type.
- **Fix:** day letters, `HOLD TO RESET`, disabled button text moved to `inkMuted`; header date and PB labels got `lineLimit` plus `minimumScaleFactor`; `ON THIS PHONE ONLY` wraps. What remains is I-01.

### R-05 Audit screenshot caught two screens mid-slide (FIXED)
- **Cause:** the tab slide runs 180 ms after the tap. **Fix:** wait 0.6 s after each tab tap in the audit test.

### R-06 App "no longer available" on the phone (FIXED)
- **Cause:** free-signing 7-day expiry (see I-06). **Fix:** rebuilt and reinstalled over the top; ride data kept. A backup of the device store is in `~/Library/Caches/trace-backup-2026-10-28`.

### R-07 Wrong test expectation: `quick` ride PBs (FIXED)
- My expectation was `["TOP SPEED"]`; the ride also holds 10 KM. Test corrected to `["TOP SPEED", "10 KM"]`.

### R-08 Simulator tests ran on the wrong data (FIXED)
- **Broke:** the UI test runner reinstalls the app, which gave it an empty store, so the cold-open test never found a ₹ amount (16 to 18 s timeouts, not real timings).
- **Cause (two layers):** the restored store was copied in, but (1) a test-seeded ride from an earlier run stayed on top of the list and (2) the app scopes every query by the owner ID saved in UserDefaults (`localStubOwnerID`); a fresh install makes a new ID, so the restored rides were invisible.
- **Fix:** `-restoreFrom <dir>` (debug only, `DebugSeed.restore`) replaces the store on every launch, and the tests pass `-localStubOwnerID <phone's owner UUID>`. The cold-open test then listed both real rides, the 24 Oct one with ₹250.

## Tooling quirks
- `xcodebuild` prints "Executed 0 tests" for Swift Testing; the real result is the "Test run with N tests ... passed" line.
- SourceKit "Cannot find type" diagnostics in single files are index noise, not build errors.
- Recursive `grep -r --include` sometimes returned nothing in the sandbox; `find ... -print0 | xargs -0 grep` worked.
- `ctx_execute_file` gave an empty `$FILE_PATH`; use `ctx_execute` with `cat`.
- A command piped through `grep` shows no output until `xcodebuild` ends.
