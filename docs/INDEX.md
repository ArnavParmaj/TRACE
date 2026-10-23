# Documentation index

Everything in this project is written down. Read the relevant document before
asking a question it already answers.

## Product
- `product/PRD.md` — the full product requirements document. Start here.
- `product/SCOPE.md` — pillars, v1/v1.5/v2 phasing, privacy rule, foundation rules.
- `product/ROADMAP.md` — milestones M0–M8 to v1, then v1.5/v2/v3, each with exit gates.
- `product/SCREENS.md` — navigation map, every v1 screen, its layout and states, key flows,
  open UX decisions.

## Engineering
- `engineering/ARCHITECTURE.md` — layers, capture path, GPS strategy, build order,
  free-signing constraints, the App Groups risk.
- `engineering/DATA-MODEL.md` — every entity, universal sync fields, the fusion rule.
- `engineering/BUILD-PLAN.md` — week 1, task by task, with hard checkpoints.
- `engineering/M2-RIDE-TEST.md` — the real-road exit test for the recorder: steps and
  what to write down.

## Design
- `../design/DESIGN.md` — frozen design language, tokens, type, components.
- `design-notes/` — supporting design rationale and exploration notes.
- `../design/icon/render.swift` — draws the app icon PNGs into `TRACE/Assets.xcassets/AppIcon.appiconset`
  (`swift design/icon/render.swift`). Concepts canvas (private): https://claude.ai/artifact/Hh8eidwrmvYjq4qL3qwjdN
- Prototype canvas (private): https://claude.ai/artifact/MTdvxrwvJhGdanmtdvQe9Q — 9 clickable
  v1 boards (Today = artboard E, Ride mode = F), the visual source of truth the app is
  matched against (decision 65). `SCREENS.md` is the spec.

## Cross-cutting
- `DECISIONS.md` — numbered, append-only decision log with rationale. Every real
  decision lands here. Never rewrite a row; add a new one that supersedes it.
- `../CLAUDE.md` — the invariants Claude Code must not violate.
- `../CONTEXT.md` — cold-start orientation: what this is, why it looks this way,
  what the constraints are, where things stand. Narrative, not authoritative.

## Conventions for new documents
- Product documents (specs, user stories, personas, roadmaps) go in `product/`.
- Technical documents (API notes, test plans, migration guides) go in
  `engineering/`.
- Design rationale goes in `design-notes/`; frozen design tokens stay in
  `design/DESIGN.md`.
- Add every new document to this index in the same change that creates it.
