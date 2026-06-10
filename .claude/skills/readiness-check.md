# Readiness Check Skill

Run this skill to verify that state is ready for a phase gate. Invoked manually
by the PM or gate approver before advancing to the next phase. You are
read-only: you check and report, you never edit state.

This is the minimal real skill (v0.7). It runs the six state-quality criteria
plus the two pre-build existence checks. Gate definitions live in
`docs/implementation-guide.md` §19; this skill is the check, not the gate
policy.

## Your inputs

- `state-index.yaml` and `project.yaml` at the repo root.
- The **gate** being checked (e.g. the build gate). The existence checks below
  apply only at the build gate.
- Entry files loaded on demand for the criteria that need their contents.

Skip `status: rejected | deferred | obsolete` entries throughout (per the deprioritized-entries rule
(docs/implementation-guide.md, Rules for Working with State): rejected/deferred/obsolete entries never gate a phase).

## State-quality criteria

1. **Approved features have acceptance criteria.** Every feature with
   `status: approved` (or later) has a non-empty `acceptance-criteria`.
   — blocking.
2. **Critical rules have test-scenarios.** Every rule with `severity: critical`
   has a non-empty `test-scenarios`. — blocking.
3. **No approved feature is blocked by an open question.** No `status: approved`
   feature lists an `open-questions` target whose question is `status: open`.
   — blocking.
4. **Entities have at least one field.** Every entity has a non-empty `fields`.
   — blocking.
5. **Flows reference real, live features.** Every feature referenced by a flow
   step exists and is not `status: rejected`; every flow references at least
   one role whose file exists. — blocking.
6. **Provenance is complete.** Every entry (except `feedback/`, which is itself
   the source) has provenance, and each provenance line has a `YYYY-MM-DD` date
   and a source. — warning on `proposed`/`draft` entries; blocking on
   `approved`/`complete`.

## Pre-build existence checks (build gate only)

Two documents must *exist* before a build starts — they have been missed in
practice, so the gate enforces presence (not content; content generation is
deferred):

7. **Project `design.md` exists.** — blocking at the build gate.
8. **The code repository's `CLAUDE.md` exists.** (The build-target repo, the
   one the coding agent will read. Its path is provided by the gate approver.)
   — blocking at the build gate.

Existence only: a present-but-thin document passes here; the build brief's
"Gaps & confidence" trailer lists these as a second net.

## Output format

```
Readiness check — <gate> — <date>

✅ <criterion>
⚠️  <criterion> (warning — does not block)
❌  <criterion> (blocking)

Summary: N blocking, N warnings. [Ready / Not ready] for <gate>.
```

List one line per criterion (1–8; show 7 and 8 only at the build gate). For
every ❌ and ⚠️, name the offending entries so the PM can act. End with the
verdict: **Ready** only if zero blocking findings.

## Rules you never break

- You never edit state. You only check and report.
- You do not advance the gate yourself — you inform the human approver.
- You skip deprioritized entries; they never block a phase.
- The two existence checks are presence-only — never judge the documents'
  content here.
