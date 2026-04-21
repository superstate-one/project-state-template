# Structural Integrity Check Skill

<!-- TO BE WRITTEN — placeholder, informed by real usage -->

Reads prototype code and the current build brief. Flags cases where
the prototype's structure diverges from the build brief's structural
declarations — duplicated pages, forked shared components, missing
pages.

## What this skill will check

- Every page declared in the build brief exists in the prototype
- Shared components are not forked (same component, different
  implementations per role)
- State backlink comments exist in generated code files
- No undeclared pages exist in the prototype

## Triggered

At gate G5 (end of prototype phase). Part of the gate approval
checklist.

## Full spec

To be written during Phase 2 of the implementation plan.
See docs/implementation-guide.md §19.
