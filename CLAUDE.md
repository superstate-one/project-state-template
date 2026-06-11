# CLAUDE.md — Project State Instructions

This is a Project State repository. You are maintaining a structured,
machine-readable description of a client project. Read this file before
doing anything else.

## Core rules

1. Never edit files in `generated/` directly.
2. Humans normally don't edit canonical entries. Use the state-updater
   skill to propose changes. Humans review human-tier changes with
   line-item granularity; auto-tier changes are handled per the review
   tiers (see "Review tiers").
3. Every state change appends to the affected entry's provenance.
4. Human-tier changes always require explicit human approval before
   commit. Auto-tier changes follow `review-policy.auto-commit` in
   `project.yaml` (`true`, the default = the AI commits them
   immediately; `false` = they are bulk-accepted at review time).
   Every auto-committed change carries `approved-by: auto-policy` in
   its provenance stamp.
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
14. Types, never instances: the repo stores entity *definitions*, rules,
    decisions, and policies — never individual records (a specific
    customer, a specific credit, a specific order). Instance data lives
    in the client's systems, referenced via `integrations/`. The
    state-updater rejects instance data at extraction and flags it in
    the extraction report, the same way it flags credentials.

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

## Review tiers

Every proposed change carries `review-tier: human | auto` (assigned by the
state-updater, recorded on the feedback entry's `extracted-items`).

- **Human tier** — reviewed line-item by a human, always: change-of-mind
  (Case 3), correction (Case 4), any change touching a `verified` entry,
  critical rules, decisions, new `contradicts` links, the *direct* change
  to a hub entry (fan-in above `review-policy.fan-in-threshold`), and
  anything the AI is unsure how to classify. Unsure → human, always.
- **Auto tier** — additions and refinements to non-critical, non-verified
  entries, and mechanical propagation updates (reference re-stamps,
  provenance appends on one-hop targets). Auto-tier changes always enter
  with `confidence: asserted` — auto-acceptance never raises confidence,
  and verification remains human-only regardless of tier.

Commit behavior is set by the `review-policy` block in `project.yaml`
(`auto-commit: true | false`, default `true`; `fan-in-threshold: <N>`,
default `20`). Auto-tier activity is summarized in a digest in the
extraction report rather than listed line-item.

**Fan-in rule:** when a changed entry is referenced by more entries than
`fan-in-threshold`, its spokes' mechanical updates are auto-tier by
definition and reported as a count ("84 references re-stamped"); the hub
change itself is always human-tier. Rationale: see `docs/scaling.md`.

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
one-hop propagation target, AND the state-index.yaml changes (emitted as
entry-block patches; see the state-updater skill).

Produce THREE artifacts: extraction report (with high-risk items at
the top, topic + short quote sourcing, human-tier items line-item and
auto-tier items as a digest), structured diff (with direct vs
propagated separation), and a draft feedback.yaml.

Wait for human review of human-tier changes before committing them.
Auto-tier changes follow `review-policy.auto-commit` (see "Review
tiers").

Raw transcripts and recordings are never stored in the repo: upload
them to external file storage (e.g. Drive), register the link as a
`sources/` entry, and have the feedback entry hold only the summary,
extracted items, and source reference.

## When asked to regenerate a view

Use the appropriate generator at `.claude/generators/generate-<view>.md`.
Generators are on-demand only. Skip rejected/deferred/obsolete entries
by default.

## When asked to check readiness for a phase

Use the readiness-check skill at `.claude/skills/readiness-check.md`.

## When code has diverged from state (phase gate triggered)

Use the drift-detector skill at `.claude/skills/drift-detector.md`.
Triggered by the gate approver at G5, G11, or G15.

## When the repo grows large

`docs/scaling.md` defines the scaling levels (whole-index → two-tier
index → grep query → embeddings) and the triggers for moving between
them. Take no action until a trigger fires; when one does, follow that
doc instead of improvising.

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
- `features/F<NNNN>-<slug>.yaml` — product features
- `flows/<slug>.yaml` — user journeys
- `rules/R<NNNN>-<slug>.yaml` — business rules
- `integrations/<slug>.yaml` — third-party services
- `sources/<slug>.yaml` — external document registry (links, never files)
- `decisions/D<NNNN>-<slug>.md` — ADR-style decisions
- `questions/Q<NNNN>-<slug>.md` — open questions
- `feedback/<date>-<slug>.yaml` — immutable record of any raw ingested input
  (transcripts, memos, emails, research)
- `risks/K<NNNN>-<slug>.md` — known risks
- `stakeholders/S<NNNN>-<slug>.md` — named people at the client

IDs: one letter + f