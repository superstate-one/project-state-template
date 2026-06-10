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

## Gaps & confidence (document trailer)

Every generated document ends with a **"Gaps & confidence"** section so the
consuming agent never mistakes uncertainty for fact:

- **Unverified claims it leans on** — entries whose `confidence` is not
  `verified`, with their label carried forward (anti-laundering, CLAUDE.md
  rule 13). If any are critical, add the soft nudge: "this document leans on N
  unverified critical claims — run verify-claim first?" Never block generation.
- **Stale entries (computed)** — entries whose `re-verify-after` is in the past,
  computed at read time; no state is written.
- **Blocking open questions** — `status: open` questions referenced by any
  included entry.

## Invocation

"Claude, regenerate the backend plan."

Output committed to `generated/backend-plan.md`.

## Rules

- Write the document in the repo's `language` (`project.yaml`; absent = `en`).
  Keys, IDs, and statuses stay English; prose is in the declared language.
- Skip features with `status: rejected | deferred`
- Skip obsolete decisions
- Entities still marked `fictional-in-prototype: true` are flagged
  with a promotion checklist reminder

## Full spec

To be written during Phase 3 Day 7 of the implementation plan.
See docs/implementation-guide.md §11.
