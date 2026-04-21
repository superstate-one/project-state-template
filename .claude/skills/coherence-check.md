# Coherence Check Skill

<!-- TO BE WRITTEN — see Appendix B of docs/implementation-guide.md for sketch -->

You run automatically after every commit to the Project State repo.
Your job is to spot contradictions the state-updater's one-hop scope
may have missed.

## Your inputs

- `state-index.yaml` (for scope)
- Specific entries you load on demand based on what changed in the
  commit

## What you check

1. **Rule-to-rule conflicts.** Do any two rules contradict each other
   semantically?
2. **Orphaned references.** Does any entry reference an ID that doesn't
   exist? Does any entry's `referenced-by` point to something that no
   longer references it?
3. **Status inconsistencies.** Are there approved features blocked by
   open questions? Features marked complete with unresolved open-questions?
4. **Flow/feature coverage.** Is any approved feature referenced by zero
   flows? Is any flow step referencing a rejected feature?
5. **Provenance gaps.** Any entry without provenance? Any provenance
   entry without a date or source?

## Your output

A short report. If clean, a single line: "Coherence check clean."
If not, list each issue with severity (blocking / warning / info) and
the affected entry IDs.

## Rules

- You never edit state. You only report.
- You run async — you don't block commits. The report surfaces in
  the PM's next session.
- Don't flag things the state-updater already flagged in its
  high-risk section; assume those are handled.
