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
--diagonal        #1A1714   unlit decorative diagonals
--ink             #F2EFE9   primary text
--ink-dim         #C9C5BF   secondary text
--ink-muted       #8A8681   labels, units
--ink-faint       #6E6B67   footnotes, slugs
--accent          #FF8A3D   amber. live state, due-soon, primary action
--alarm           #E0241B   red. STRUCTURAL/urgent only
--alarm-ink       #FF6A5F   red text on black (contrast-safe; #E0241B is not)
--warn            #E8B84B   amber-yellow, expiry countdown chips
```

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
- **Capture button**: black fill, 2px amber border, 10px red left spine,
  min-height 106pt, left-aligned label.
- **Gauge**: 4px stroked arc, unlit track `#1E1C1A`, three tick marks. Never filled.
- **Progress**: 3px bar, unlit track, accent fill.
- **Alarm rail**: 1px red border with 10px red left spine. Only for expired/overdue.

## Accessibility
- Touch targets >= 60pt everywhere (gloves), not the 44pt minimum.
- Ride mode: tap-anywhere capture, no precision targets.
- All body text >= 4.5:1 on black; muted labels >= 3:1 and never below 11px.
