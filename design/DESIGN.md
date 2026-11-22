# Design language — FROZEN 2026-10-21

**Direction: OLED Splice.** Hybrid B (Instrument) structure + Hybrid D (Agit-Print)
typography and attitude, on a true-black ground. Chosen over pure D because D spends
red on decoration, leaving no alarm colour for overdue service and expired documents.

Reference artboards: E (Today) and F (Ride mode) on the design canvas.

## Ground rules
1. Ground is `#000000`. Not near-black. OLED pixels are then genuinely off.
2. No large filled colour fields. Outlines, hairlines and thin arcs instead of slabs.
   A filled button is lit pixels; a bordered one is not.
3. Red is reserved. It means overdue / expired / urgent. It is never decoration.
4. Agit-Print character is carried by *unlit* structure: hairline diagonals,
   numbered section chips, stencil slugs, condensed caps.
5. Ride mode lights as little as possible — see F.

## Tokens
```
--ground          #000000   true black, every screen
--surface-line    #1E1C1A   hairline dividers inside a section
--surface-rule    #2A2724   section boundaries
--diagonal        #2C2824   hairline decorative diagonals (visible on OLED; was #1A1714, decision 65)
--ink             #F2EFE9   primary text
--ink-dim         #C9C5BF   secondary text
--ink-muted       #8A8681   labels, units
--ink-faint       #6E6B67   footnotes, slugs
--accent          #FF7A1A   amber. live state, due-soon, primary action (was #FF8A3D, decision 65)
--alarm           #E0241B   red. STRUCTURAL/urgent only
--alarm-ink       #FF6A5F   red text on black (contrast-safe; #E0241B is not)
--warn            #E8B84B   amber-yellow, expiry countdown chips
```

Tokens are drawn in Display P3 on device (decision 65), so they read more vivid than in a browser.

Note: `#E0241B` passes as a border or fill but fails contrast as small text on black.
Text that must be red uses `--alarm-ink`.

## Type
- **Oswald** 500/600/700 — wordmark, all numerals, section labels, stat displays.
  Condensed caps carry the Agit-Print voice.
- **Roboto Condensed** 400/500/700 — body, row labels, helper text.
- Numerals are always Oswald. This is the single strongest identity carrier.

## Components
- **Section header**: numbered chip (`01`, inverted, muted ground) + letter-spaced
  caps label + hairline rule filling remaining width.
- **Capture button**: black fill, 2px amber border, 10px amber left spine,
  min-height 106pt, left-aligned label. (Spine was red until decision 36: red is
  reserved, so a red spine on the most-used control broke rule 3.)
- **Gauge**: 4px stroked arc, unlit track `#1E1C1A`, three tick marks. Never filled.
- **Progress**: 3px bar, unlit track, accent fill.
- **Alarm rail**: 1px red border with 10px red left spine. Only for expired/overdue.

## Motion (decision 101)
Motion is how the app answers back, never decoration. Tokens live in `TRACE/Design/Motion.swift`.
- **Only unlit structure moves**: outlines, arcs, hairlines, Oswald figures. No filled slab lights up.
- **Ignition**: the first time a tab opens each launch, its blocks rise in (0.5 s, 60 ms stagger,
  8 steps at most) and section rules extend. Returning to a tab shows it at rest.
- **Rolling numbers**: Oswald figures roll digit by digit when they change (`.numericText`).
- **Confirmations**: a save shows an amber outlined stamp (LOGGED, SAVED, DONE · km), an outline
  ring, and the success haptic, all on one frame. The sheet holds 0.55 s so the stamp is seen.
- **Tab bar**: one amber underline springs between tabs, with a selection tick instead of a press tap.
- **Ride mode**: the gauge eases between readings, self-tests on open (to the end of the dial and back),
  nine ticks sit outside the band, the REC dot breathes once every 4 s. Nothing animates continuously.
- **Red** moves only for overdue or expired.
- **Reduce Motion**: every move becomes a 0.2 s fade or nothing. Haptics stay.
- **Voice**: empty sections get a short amber kicker and still say what to do. No slogans about
  privacy or the product: the storage fact is one faint line at the bottom of Settings.

## Accessibility
- Touch targets >= 60pt everywhere (gloves), not the 44pt minimum.
- Ride mode: tap-anywhere capture, no precision targets.
- All body text >= 4.5:1 on black; muted labels >= 3:1 and never below 11px.
