# Generator: Build Brief

<!-- TO BE WRITTEN — placeholder, informed by real usage -->

Produces `generated/build-brief.md` on demand. Consumer: prototype
coding agent. Triggered at Phase 2/3 start; regenerated after major
feedback cycles.

## What this generator must produce

1. **Page inventory** — every page with URL path
2. **Role access matrix** — which roles see which pages
3. **Shared page declarations** — pages shared across roles
4. **Shared component inventory** — components used by more than one page
5. **Data shape declarations** — what data each page displays and accepts
6. **Rule enforcement points** — which rules are enforced where
7. **Routing map** — how pages connect
8. **State backlink conventions** — header comments for generated files:
   ```
   // Generated from: F0001, F0002
   // Enforces: R0001
   // Part of flow: add-first-building
   ```

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

- **Missing pre-build documents** — list the project `design.md` and the code
  repository's `CLAUDE.md` if either is absent (a second net behind the
  readiness check's existence checks).

## Invocation

"Claude, regenerate the build brief."

Output committed to `generated/build-brief.md` with message:
`build-brief: regenerated from state as of <commit-sha>`

## Rules

- Write the document in the repo's `language` (`project.yaml`; absent = `en`).
  Keys, IDs, and statuses stay English; prose is in the declared language.
- Skip features with `status: rejected | deferred`
- Skip obsolete decisions and closed risks
- Deterministic section ordering — regenerating with unchanged state
  produces near-identical output

## Full spec

To be written during Phase 1 Day 3 of the implementation plan.
See docs/implementation-guide.md §11.
