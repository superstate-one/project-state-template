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
   // Generated from: F001, F002
   // Enforces: R001
   // Part of flow: add-first-building
   ```

## Invocation

"Claude, regenerate the build brief."

Output committed to `generated/build-brief.md` with message:
`build-brief: regenerated from state as of <commit-sha>`

## Rules

- Skip features with `status: rejected | deferred`
- Skip obsolete decisions and closed risks
- Deterministic section ordering — regenerating with unchanged state
  produces near-identical output

## Full spec

To be written during Phase 1 Day 3 of the implementation plan.
See docs/implementation-guide.md §11.
