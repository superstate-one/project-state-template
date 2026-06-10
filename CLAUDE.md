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
8. Language is per-repo. `project.yaml`'s `language` declares the primary
   content language (absent = `en`). Structure is always English — schema
   keys, IDs, statuses, folder names, controlled vocabularies. Content
   (titles, descriptions, rationale, quotes) is in the declared language.
   Quotes and domain terms stay verbatim; skills never translate or "clean"
   mixed phrases, and never write language arrays or per-field tags.
9. Always `git pull` before running the state-updater.
10. The state-updater maintains state-index.yaml as part of its own diff.
    Do not run a separate index rebuilder.
11. Propagation is one hop only — entries that directly reference the
    affected entry via structured fields. No transitive closure.
    Prose mentions don't count.
12. Coherence check runs automatically after every commit to catch
    what the state-updater missed.
13. Anti-laundering: whenever a skill or generator uses a non-verified
    claim, its trust label travels with it. A `derived` or `asserted`
    claim may never be restated as established fact. Generation is never
    blocked — a generator leaning on unverified critical claims adds a
    soft nudge ("this leans on N unverified critical claims — run
    verify-claim first?"); the human decides.

## Trust labels

Every entry may carry trust labels (all optional, safe defaults — this is
what keeps pre-0.7 repos valid). Canonical format lives in `docs/schema.md`.

- `confidence: verified | asserted | derived` — absent = `asserted`.
  `verified` = a human confirmed it; `asserted` = someone said it, recorded
  as-is; `derived` = the AI inferred it.
- `asserted-by` — who said it (`client`, a stakeholder ID, a team member, an
  AI agent like `voice-agent` / `state-updater`).
- `claim-type: fact | preference | policy | estimate`.
- `scope: global | team | person` — absent = `global`.
- `re-verify-after: <date>` — optional expiry on trust.

Rules:
- **Only a human grants `verified`.** The AI never promotes its own claims.
- **De-verify on modify:** any change to a `verified` entry resets its
  confidence to `asserted`, flagged in the extraction report — unless a
  listed verifier approves the change in the same session, in which case it
  stays verified with a fresh provenance stamp. Verification covers an
  entry's current content, never its history.
- `confidence` is its own field; it never overloads `status`.
- **Staleness is computed, never stored.** Any entry whose `re-verify-after`
  is in the past is treated as stale at read time (verify-claim lists it
  first, generators flag it). No `stale` field is ever written.
- **`inferred` is removed.** Personas use `confidence`. Skills read a legacy
  `inferred` as an alias (`true` → `derived`, `false` → `asserted`) and never
  write it again.
- **Who verifies:** project-state — anyone on the team. company-brain — the
  `verifiers:` list in `project.yaml`.

## Semantic links

The index carries typed relationship links inside the `references` /
`referenced-by` maps. The vocabulary is **only** these two pairs (new types
require a schema bump):

- `contradicts` / `contradicted-by` — these entries conflict.
- `derived-from` / `derives` — this claim was inferred from that entry.

`contradicts` links are proposed by the coherence check, approved by a human,
and written by the state-updater; they persist until reconciliation clears
them.

## Modes

This template runs in one of two modes, set at first-run and written to
`project.yaml` as `mode: project-state | company-brain` (absent =
`project-state`). The files are identical in both; behavior differences live
in the skills, which branch on the flag. Full semantics — including the
`visibility` mechanism, the access model, and `scope` vs `visibility` — are in
`docs/modes.md`.

In company-brain mode, `visibility: company | team/<slug> | restricted` is
mandatory on every new entry (the state-updater rejects a diff that omits it;
absent = `restricted`, fail-closed). Unused in project-state.

## Schema-version authority

The schema version appears in three places: `.claude/schema-version.yaml`
(template-owned, updated by pulls), `project.yaml`, and the index header. The
**single authority is `.claude/schema-version.yaml`** — it is what the update
script gates on. The other two mean "schema at last content write," are
informational, and are expected to lag.

## Format authority

`docs/schema.md` is the canonical format for every entry type. Skills follow
it rather than looking in entry folders for examples — the template ships
none.

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
sources, generated, project.yaml, state-index.yaml) is local. To pull
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
`stakeholders/`, `integrations/`, `sources/`, `generated/`) and the
`project.yaml` / `state-index.yaml` files are never touched by the updater.
The full whitelist of template-owned paths is at the top of the script.

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
- `sources/<slug>.yaml` — external document registry (links, never files)
- `decisions/D<NNN>-<slug>.md` — ADR-style decisions
- `questions/Q<NNN>-<slug>.md` — open questions
- `feedback/<date>-<slug>.yaml` — immutable record of any raw ingested input
  (transcripts, memos, emails, research)
- `risks/K<NNN>-<slug>.md` — known risks
- `stakeholders/S<NNN>-<slug>.md` — named people at the client

IDs: one letter + three digits (F001, R001, D001, Q001, K001, S001).
Roles, entities, flows, integrations, sources use slugs. IDs are never
reused. See `docs/schema.md` for the canonical format of every type.

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
   a 1-paragraph summary, the **mode** (`project-state` or
   `company-brain`), and the **language**. Language defaults to `en` in
   project-state (override when the client domain demands it); in
   company-brain it is a mandatory choice with no default. In
   company-brain mode also ask for the **verifiers** list (who may grant
   `verified`) and any **teams** (the slugs behind `team/<slug>`
   visibility).
2. Update `project.yaml` with these values, including `mode` and
   `language`, and set `created` to today's date.
   - **project-state:** `status: discovery`, `outcome: null`,
     `lessons-learned: []`.
   - **company-brain:** `status: active`; add `verifiers:` and `teams:`;
     omit the commercial / outcome / lessons-learned / strategic-context
     blocks.
3. Update `README.md`: replace the "How to use this template" section
   with a project-specific "About this project" section that states
   the client, industry, and summary. Leave the rest of the README
   (folder layout, entry types, workflow, key rules) intact.
4. Commit with message: `init: project setup for <client-name>`.

The template ships zero example entries, so there is nothing to clear —
no keep-or-clear question. Do this once, on first interaction with a
fresh clone.
