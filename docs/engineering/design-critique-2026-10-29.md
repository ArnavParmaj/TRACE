---
target: all app screens
total_score: 25
max_score: 40
na_heuristics: 
p0_count: 0
p1_count: 6
target_identity: "file:/Users/arnavparmaj/Projects/TRACE/TRACE/App"
timestamp: 2026-10-28T20-02-33Z
slug: trace-app
---
Method: design review only (detector not applicable, native platform). Code review of all 14 screens against design/DESIGN.md and docs/product/SCREENS.md; no fresh simulator screenshots.

Score 25/40 (Acceptable). H1 2, H2 3, H3 2, H4 2, H5 2, H6 3, H7 3, H8 3, H9 2, H10 3.

P1
1. Location denied -> ride records nothing, shows NO GPS forever, saves 0 km. No status check or Settings link anywhere (LocationService, OnboardingView ASKED state).
2. Today ride row clock (TodayView.elapsed) uses lastFix - startedAt: freezes between fixes, counts paused time, disagrees with ride mode clock.
3. DISCARD DRAFT (ExpenseSheet) deletes in one tap, no confirm, no undo; now sits far left.
4. Today 03 DUE rows are not buttons; SCREENS says they open S12/S13.
5. Prefilled keypad fields append digits (MarkDone odometer, edit expense amount): 12480 -> 124805.
6. Money shows only the current week/month/year; last month is unreachable.

P2
7. Four different "add" styles (Money PrimaryButton, Bike accent right text, Settings centred dim TextAction, RideSheet dim left).
8. SAVE placement differs: pinned bar (Expense), mid-scroll (Task, Document, EditBike), under keypad (Odometer, MarkDone).
9. Rides rows use onTapGesture: no press feedback or haptic, no button trait.
10. Rename ride only through hidden long-press.
11. SCREENS rule 8 (soft delete + 5 s undo bar) not built; app uses confirm alerts. Doc vs code decision needed.
12. Trip meter reset has no undo.
13. Onboarding odometer SKIP stores 0 km, so km-based service maths starts from 0.
14. Picking an expense category does not open the keypad: extra tap at the pump.
15. Errors show raw localizedDescription, no retry (SCREENS rule 7).
16. System compact DatePickers (expense TIME, task LAST DONE ON, document EXPIRES ON) are under 60 pt.
17. TaskSheet HISTORY SectionHead number "" draws an empty grey chip.
18. Task interval fields use the small system number pad, unlike the 60 pt KeypadGrid elsewhere.
19. Rides 12-week chart: ~25 pt bars for gloved taps; no per-bar VoiceOver.
20. Bike tab has no ScreenHeader; other tabs do.
21. Empty SERVICE / DOCUMENTS sections show only "+ ADD", no guidance copy.
22. A live ride is invisible from Rides / Money / Bike tabs.

P3
23. Three clock formats (0:42:10, 00:42:10, 42:10).
24. Section numbers skip in ride detail when elevation/splits hide.
25. Category case mixes "Fuel" and "FUEL".
26. DueRow uses warn for service due-soon (DESIGN: accent) and a 4 pt spine without the 1 px border the alarm rail spec names.
27. Money 6-month chart y-axis has no rupee format; week caption across months reads "27–2 NOV".
28. Onboarding comment says "Always" is asked at first ride; nothing asks it.
