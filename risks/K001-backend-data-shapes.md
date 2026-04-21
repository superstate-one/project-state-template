---
id: K001
title: Backend cannot match prototype data shapes without rework
status: open
severity: medium
---

## Risk

The prototype was built with fictional data shapes optimised for rapid UI
iteration. When the backend is built in Phase 6, it may produce different
field names, types, or nesting than the prototype expects — breaking the
frontend without a clear error.

Specifically at risk:
- `building.apartment-count` (integer in state; prototype may have stored
  as string in localStorage mock)
- `apartment.monthly-rent` (float in state; prototype may return null vs 0
  inconsistently)
- Aggregate fields on the dashboard (computed server-side vs computed
  client-side in the prototype)

## Mitigation

1. The Phase 5 backend plan explicitly maps each fictional prototype field
   to its real backend type. Any shape change becomes a `decisions/` entry.
2. The build brief generator (Phase 2) includes explicit data shape
   declarations per page so the coding agent builds against them from the start.
3. Entities with `fictional-in-prototype: true` must complete the promotion
   checklist (§8.3) before the backend plan is written — field types tightened,
   constraints verified.

## Provenance

- 2026-04-22: Identified during prototype review planning; kaloian flagged
  that the apartment-count dropdown fix would expose a type mismatch if the
  mock data was seeded as strings.
