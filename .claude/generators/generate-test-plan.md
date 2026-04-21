# Generator: Test Plan

<!-- TO BE WRITTEN — placeholder, informed by real usage -->

Produces `generated/test-plan.md` on demand. Consumer: testing agents
(all three layers). Triggered at Phase 7 start; regenerated end-of-day
or when 3+ test findings have accumulated.

## Three testing layers this generator must produce

**Layer 1 — Scripted scenarios (Playwright)**
- One scenario per flow happy path
- One assertion per rule test-scenario (accept and reject)
- Each test includes a state backlink: which F/R entry it enforces

**Layer 2 — Persona exploration**
- One persona agent per role, derived from roles/ goals, pain-points,
  and flows/ test-persona-hints
- Suggested action scripts from features/ edge-cases

**Layer 3 — Boundary / negative testing**
- All rules/ logic-gap-probes aggregated and prioritised
- Critical-severity rules first
- entities/ field types → type-violation attempts
- flows/ failure-modes → confirm graceful failure

## Invocation

"Claude, regenerate the test plan."

Output committed to `generated/test-plan.md`. Old generated tests
replaced wholesale.

## Rules

- Skip features with `status: rejected | deferred`
- Skip closed risks
- Every test has a state backlink

## Full spec

To be written during Phase 3 Day 6 of the implementation plan.
See docs/implementation-guide.md §12.
