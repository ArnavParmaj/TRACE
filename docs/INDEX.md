# Documentation index

Everything in this project is written down. Read the relevant document before
asking a question it already answers.

## Product
- `product/PRD.md` — the full product requirements document. Start here.
- `product/SCOPE.md` — pillars, v1/v1.5/v2 phasing, privacy rule, foundation rules.

## Engineering
- `engineering/ARCHITECTURE.md` — layers, capture path, GPS strategy, build order,
  free-signing constraints, the App Groups risk.
- `engineering/DATA-MODEL.md` — every entity, universal sync fields, the fusion rule.
- `engineering/BUILD-PLAN.md` — week 1, task by task, with hard checkpoints.

## Design
- `../design/DESIGN.md` — frozen design language, tokens, type, components.
- `design-notes/` — supporting design rationale and exploration notes.

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
