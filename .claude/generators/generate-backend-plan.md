# Generator: Backend Plan

<!-- TO BE WRITTEN — placeholder, informed by real usage -->

Produces `generated/backend-plan.md` on demand. Consumer: backend
coding agent. Triggered at Phase 5 start; regenerated after dev
decisions.

## What this generator must produce

- Entity-to-table mapping (entities/ → database schema)
- API endpoint list derived from features and flows
- Integration connection points (where integrations/ entries touch code)
- Decision implementation notes (from decisions/ entries)
- Fictional-to-real data shape promotion map (entities with
  `fictional-in-prototype: true` get explicit migration notes)

## Invocation

"Claude, regenerate the backend plan."

Output committed to `generated/backend-plan.md`.

## Rules

- Skip features with `status: rejected | deferred`
- Skip obsolete decisions
- Entities still marked `fictional-in-prototype: true` are flagged
  with a promotion checklist reminder

## Full spec

To be written during Phase 3 Day 7 of the implementation plan.
See docs/implementation-guide.md §11.
