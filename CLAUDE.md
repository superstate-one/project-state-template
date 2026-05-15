# CLAUDE.md — Project State Instructions

This is a Project State repository. You are maintaining a structured,
machine-readable description of a client project. Read this file before
doing anything else.

## Core rules

1. Never edit files in `generated/` directly.
2. Humans normally don't edit canonical entries. Use the state-updater
   skill to propose changes. Humans review and approve with line-item
   granularity.
3. Every state change appends to the affected entry's provenance.
4. Never auto-commit. All state changes require explicit approval.
5. Classify every proposed change as addition, refinement,
   change-of-mind, or correction.
6. Feedback entries are immutable after PM review.
7. Never include credentials, API keys, or secrets. Flag suspected
   credentials in the extraction report.
8. All state is in English. Translate non-English source material first.
9. Always `git pull` before running the state-updater.
10. The state-updater maintains state-index.yaml as part of its own diff.
    Do not run a separate index rebuilder.
11. Propagation is one hop only — entries that directly reference the
    affected entry via structured fields. No transitive closure.
    Prose mentions don't count.
12. Coherence check runs automatically after every commit to catch
    what the state-updater missed.

## When new input arrives (transcript, memo, dev note, question answer)

Use the state-updater skill at `.claude/skills/state-updater.md`.

Read `state-index.yaml` first, then load only the entries affected by
the input and their one-hop references.

Propose a complete diff covering every directly-affected entry, every
one-hop propagation target, AND the updated state-index.yaml.

Produce THREE artifacts: extraction report (with high-risk items at
the top, topic + short quote sourcing), structured diff (with direct
vs propagated separation and line-item approval), and a draft
feedback.yaml.

Wait for human review before committing.

## When asked to regenerate a view

Use the appropriate generator at `.claude/generators/generate-<view>.md`.
Generators are on-demand only. Skip rejected/deferred/obsolete entries
by default.

## When asked to check readiness for a phase

Use the readiness-check skill at `.claude/skills/readiness-check.md`.

## When code has diverged from state (phase gate triggered)

Use the drift-detector skill at `.claude/skills/drift-detector.md`.
Triggered by the gate approver at G5, G11, or G15.

## When state has gotten into a bad shape

Revert to the last known-good git commit and re-apply lost changes
one at a time via the state-updater. Do not hand-repair corrupted
state.

## When the user wants to update from the template

The template (skills, generators, CLAUDE.md, schema, updater script) is
maintained centrally; project state (roles, entities, features, flows,
rules, decisions, questions, feedback, risks, stakeholders, integrations,
generated, project.yaml, state-index.yaml) is local. To pull
infrastructure updates without touching project state, use
`scripts/update-from-template.sh`:

1. Run `scripts/update-from-template.sh` first — this is a dry-run that
   shows the diff against `template/main` on template-owned paths only.
   The script self-updates as its first action, so any improvements to
   the updater itself ship with each update.
2. If the diff looks correct, re-run with `--apply`. The script stages
   the template versions of the whitelisted paths.
3. Review with `git diff --cached` and commit with a message like
   `template: pull infrastructure updates`.

Project-owned directories (`roles/`, `entities/`, `features/`, `flows/`,
`rules/`, `decisions/`, `questions/`, `feedback/`, `risks/`,
`stakeholders/`, `integrations/`, `generated/`) and the `project.yaml` /
`state-index.yaml` files are never touched by the updater. The full
whitelist of template-owned paths is at the top of the script.

If the schema major version differs, the updater refuses and points at
`docs/updating-from-template.md` for migration guidance.

## File layout

[See `docs/implementation-guide.md` §7.]

## Entry types and ID conventions

- `project.yaml` — top-level metadata, one per project
- `roles/<slug>.yaml` — user roles
- `entities/<slug>.yaml` — data entities
- `features/F<NNN>-<slug>.yaml` — product features
- `flows/<slug>.yaml` — user journeys
- `rules/R<NNN>-<slug>.yaml` — business rules
- `integrations/<slug>.yaml` — third-party services
- `decisions/D<NNN>-<slug>.md` — ADR-style decisions
- `questions/Q<NNN>-<slug>.md` — open questions
- `feedback/<date>-<slug>.yaml` — immutable session records
- `risks/K<NNN>-<slug>.md` — known risks

IDs: one letter + three digits (F001, R001, D001, Q001, K001).
Roles, entities, flows, integrations use slugs. IDs are never reused.

## Update cases

- **Case 1 — Addition:** new information, no conflict.
- **Case 2 — Refinement:** tightens an existing entry without contradicting.
- **Case 3 — Change of mind:** contradicts existing state; client changed direction.
- **Case 4 — Correction:** old entry was never correct (error or misinterpretation).

## Status transitions

When a question is answered: set `status: answered`, fill `answered: <date>`
and `answer-summary: <text>`. Keep the original body intact. Never delete
the file.

When a decision becomes obsolete: set `status: obsolete` and append a dated
note to Provenance explaining what replaced it. Never delete.

When a feature is rejected or deferred: set `status: rejected | deferred`.
The entry stays in the repo forever; generators skip it by default.

When a risk is closed: set `status: closed`. Do not delete. Closed risks
remain available to the pattern library at archival.

## Commit message format

`<entry-ID>: <summary> per <source>`

For cross-domain changes, @-mention the relevant owner.

## First-run setup (when template is cloned for a new project)

When this repository is opened for the first time after cloning from the
template (detected by `project.yaml` still containing placeholder values
like "acme-realestate" or "Acme Holdings"), before processing any input:

1. Ask the user for: project name, client name, industry, current owner,
   and a 1-paragraph summary.
2. Update `project.yaml` with these values. Set `status: discovery`,
   `created` to today's date, `outcome: null`, `lessons-learned: []`.
3. Update `README.md`: replace the "How to use this template" section
   with a project-specific "About this project" section that states
   the client, industry, and summary. Leave the rest of the README
   (folder layout, entry types, workflow, key rules) intact.
4. Ask whether the user wants to clear the example entries (delete all
   files in `roles/`, `entities/`, `features/`, `flows/`, `rules/`,
   `integrations/`, `decisions/`, `questions/`, `feedback/`, `risks/`
   and reset `state-index.yaml` to empty) or keep them as reference.
   Default: clear.
5. If cleared, also clear `state-index.yaml`: reset to schema header
   plus empty `entries: []`.
6. Commit with message: `init: project setup for <client-name>`.

Do this once, on first interaction with a fresh clone.
