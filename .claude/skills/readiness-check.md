# Readiness Check Skill

<!-- TO BE WRITTEN — placeholder, informed by real usage -->

Run this skill to verify that state is ready for a phase gate.
Invoked manually by the PM or gate approver before advancing to
the next phase.

## What this skill will check (per gate)

- All approved features have acceptance criteria
- All critical rules have test-scenarios
- No approved feature is blocked by an open question
- All entities have at least one field
- All flows reference features that exist and are not rejected
- All provenance entries have a date and source

## Output format (sketch)

```
Readiness check — <gate> — <date>

✅ <criterion>
⚠️  <criterion> (warning — does not block)
❌  <criterion> (blocking)

Summary: N blocking, N warnings. [Ready / Not ready] for Phase N.
```

## Full spec

To be written after first real project usage. See
docs/implementation-guide.md §19 for gate definitions.
