# M2 ride test — the recorder's exit gate

M2 passes only when all three are true on a real road (ROADMAP M2):
1. A ride of **over an hour** records with the phone locked in a pocket or mount.
2. **Force-killed mid-ride**, then reopened, it recovers with **≤ 15 s missing**.
3. **Battery drain per hour** is measured and written in `docs/DECISIONS.md`.

If any fails, stop and fix before M3.

## Before the ride
- Install a fresh build (free signing expires after 7 days).
- Charge to 100% and note the time. Close other navigation apps.
- First launch asks for location: choose **Allow While Using App**. Motion & Fitness
  (barometer, for climb) is asked on first start.
- Settings > Battery: note the level, so drain can be read off the graph afterwards.

## On the ride
1. TODAY tab → **START RIDE**. Wait for STATE to read RECORDING and GPS ±5–10 m.
2. Lock the phone. The blue location pill should show in the status bar.
3. Ride at least 30 minutes, with a stop of over 2 minutes (signal, chai, fuel).
   At one stop, tap **PAUSE** (heavy tap felt; the location arrow disappears), wait a
   minute, tap **RESUME** (success haptic). PAUSED should show that minute.
4. **Force-kill:** unlock, swipe up, swipe TRACE away. Note the time of day.
5. Reopen TRACE. The card should read "A ride from HH:MM didn't finish…".
   Check "saved up to" is within 15 s of the kill time. Tap **RESUME**.
6. Ride another 30+ minutes, then **STOP** (warning haptic on the confirm, success on stop).

## Write down
- Total time, battery at start and end → drain %/h. Append it as a decision row.
- Saved-up-to time vs kill time (seconds lost).
- DISTANCE vs bike odometer (GPS should be within ~2–5%, decision 24).
- STOPS count vs stops you remember making for over 2 minutes.
- Did every button tap and ride action buzz through your gloves? Any that felt wrong?
- Anything odd: a jump in distance, a gap, CLIMB obviously wrong.

## Known limits of the M2 build
- Debug screen only; no map or ride list yet (M7).
- Climb reads 0 in the simulator (no barometer), real on the phone.
- A ride auto-closes after 30 minutes standing within 50 m of one spot (decision 50).
  Gridlock creep and level-crossing waits under 30 minutes keep the ride open; a long
  lunch stop ends it at the moment you stopped.
- Paused, GPS is off: nothing records, and a stop while paused ends the ride at the
  moment you paused. A pause has no auto-close, so a forgotten pause stays open.
- If iOS ends the app in the background (memory pressure), it behaves like a kill:
  reopen and RESUME.
