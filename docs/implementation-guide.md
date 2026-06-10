# Project State — Complete Implementation Guide

**What it is, why it exists, how it works, and how to build it.**

This document is the single reference for implementing the Project State system at Superstate. It contains everything needed to understand the concept, set up the infrastructure, and start using it on a real project.

**Version 0.7.** The canonical entry format lives in `docs/schema.md` and the two modes (project-state, company-brain) in `docs/modes.md`; the live skills under `.claude/skills/` are the authoritative prompts. v0.7 added the trust layer, `sources/`, semantic links, index entry-block patches, per-repo language, and company-brain mode. The full changelog is in §21; this guide carries the design rationale and the conceptual model, not field-level specs.

---

## Table of Contents

1. Company Context
2. What is Project State
3. Architecture Overview
4. The Core Loop
5. The Four Update Cases
6. Schema — Entry Types and Structure
7. Folder Layout
8. Entry Types — Full Specification
9. Rules for Working with State
10. The State-Updater — How It Works
11. Generators — What They Are and How They Work
12. How State Drives Testing
13. The Code-State Boundary
14. Human Interfaces
15. Team Workflow — Ownership and Concurrency
16. Recovery and Rework
17. Implementation Plan
18. Using Project State on a Real Project — Step by Step
19. Quality Gates in the Pipeline
20. The Pattern Library
21. Schema Versioning
22. What Project State Does NOT Do
23. Glossary

Appendix A — State-Updater Prompt (v1 draft)
Appendix B — Coherence Check Prompt (v1 draft, sketch)

---

## 1. Company Context

Superstate is a small team building custom AI-native software for businesses. The thesis: when building a custom AI-powered app costs $10K instead of $500K, the ROI of off-the-shelf SaaS collapses. The new model is custom AI-built software delivered at SaaS speed and price points.

The team:
- 1 product / UI / UX person (founder, ~20 years experience)
- 1 business / strategy person (~20 years experience)
- 1 PM / strategy person
- 2 developers (own backend infrastructure, hosting, security)
- 1 person in an undefined / user testing role (not in core pipeline for now)

The competitive moat is not automation alone — it's taste, judgment, and pattern recognition applied to automated output. The team automates volume with AI agents and uses human experience to select the best output.

The pipeline runs from lead research through AI voice agent discovery interviews, prototype building with coding AI agents, client feedback, backend development, testing, and delivery. The company has 7–10 clients at different stages. Most clients are Bulgarian. Language is per-repo: `project.yaml`'s `language` declares the primary content language (absent = `en`); structure (schema keys, IDs, statuses, controlled vocabularies) is always English, content is in the declared language, and quotes and domain terms stay verbatim.

---

## 2. What is Project State

Project State is a structured, versioned, machine-readable description of everything known about a client project. It replaces traditional documents (PRDs, spec docs, app flow docs) as the single source of truth.

Instead of maintaining multiple documents that partially overlap and must be kept in sync manually, Project State stores knowledge as small, atomic, structured entries in a git repository. Each entry describes one thing: one feature, one user role, one business rule, one decision. Machine-readable views like the build brief, backend plan, and test plan are generated from state on demand — they are disposable outputs, never edited directly.

### Why this solves real problems

**Document drift.** Today's workflow keeps PRD, app flow doc, prototype code, backend plan, and test plan as separate artifacts. They fall out of sync the moment any of them is manually touched. With Project State, every document is generated from a single canonical source; drift becomes structurally impossible because there's nothing to reconcile.

**Prototype structural mess.** When vibe-coding a large demo, the AI coding agent has no persistent memory of what already exists. It builds a page for one role, then builds the same page differently for another role because it didn't realize it's the same page. Shared components get forked. With Project State, the build brief explicitly declares every page, which roles share it, and which components are shared — before any code is written.

**Handoff loss.** Information gets compressed at every step: client → voice agent → prototype → backend → tests. "Buildings come in all sorts of weird sizes" becomes "apartment count field" becomes a dropdown with values 10, 20, 30. The original nuance is gone. With Project State, every entry records provenance — where it came from, when, with what context. Nuance is preserved as structured data, not lost in summarization.

**E2E testing that requires manual enumeration.** The testing agent today needs a human to enumerate every interaction path to try, and it still misses logic gaps (like the apartment count dropdown) because it has no structured understanding of the product. With Project State, flows, rules, and features are structured and exhaustive. The test plan generator derives comprehensive test scenarios automatically.

**No accumulated IP.** Every project starts from scratch today. Hard-won lessons from project 3 don't flow into project 11. With Project State, completed projects are archived with an `industry` tag, and Claude proposes applicable rules and lessons at new-project kickoff. See Section 20.

### Two design choices worth calling out

**Coding agents read state directly.** Unlike traditional workflows that require a prose PRD, our coding agents are given the state repo and a build brief. Prose PRDs are not generated — no one reads them, and the coding agent works better from structured YAML anyway.

**State is internal only.** Clients see the working demo and the delivered product. They do not see any generated document. If a client later asks for documentation, it is produced ad-hoc at that point. There is no handoff document generator.

---

## 3. Architecture Overview

```
┌──────────────────────────────────────────────────────────────┐
│                    HUMAN INTERFACES                          │
│  Claude Code (devs)   Claude Cowork (PM/biz/UX)   claude.ai  │
└────────────┬──────────────┬────────────────────┬─────────────┘
             ▼              ▼                    ▼
┌──────────────────────────────────────────────────────────────┐
│                    PROJECT STATE (git repo)                  │
│                                                              │
│  roles/  features/  entities/  rules/  flows/                │
│  decisions/  questions/  feedback/  integrations/  risks/    │
│  state-index.yaml    .claude/    CLAUDE.md                   │
└──────────┬───────────────────────────────┬───────────────────┘
           ▼                               ▼
┌─────────────────────┐     ┌──────────────────────────────────┐
│  STATE-UPDATER      │     │        GENERATORS                │
│  (+ coherence check │     │                                  │
│   on every commit)  │     │  Read state, produce on demand:  │
│                     │     │  - build-brief.md                │
│  Reads events,      │     │  - backend-plan.md               │
│  proposes diffs,    │     │  - test-plan.md                  │
│  maintains index    │     │                                  │
│                     │     │  All output in generated/        │
│  Human approves     │     │  NEVER edited by hand            │
└─────────────────────┘     └──────────────────────────────────┘
```

**Key architectural decisions:**

- **Git repo per project, always private.** One repo per client. GitHub team account.
- **No custom software.** Claude Code for devs, Claude Cowork for everyone else, claude.ai + GitHub as fallback. No admin panels, no databases.
- **YAML for structured data, markdown for prose.** Features, rules, entities → YAML. Decisions, questions, risks → markdown with YAML frontmatter.
- **No PRD, no app-flow, no handoff generators.** Coding agents read state directly. Clients see no documents.
- **Overwrite + git history, not supersession.** Entries are updated in place. Git preserves the change history. Provenance is appended inside the entry so evolution can be read without diving into git.
- **Generated documents are disposable and on-demand.** Everything in `generated/` can be deleted and regenerated. No auto-regeneration on commit.
- **The index is part of every state-updater diff.** No separate rebuilder skill.
- **LLM proposes, human approves, with line-item granularity.** The human reviews direct changes and propagated changes independently.
- **Coherence check runs on every commit.** Cheap, async, catches contradictions the state-updater missed.

---

## 4. The Core Loop

This is the only update mechanism. No exceptions.

```
Event happens (meeting, feedback, dev decision, test finding, internal decision)
    │
    ▼
Raw input is captured (transcript, memo, dev note, bug report, short memo)
    │
    ▼
A human drops the input into the repo and tells Claude to process it
    │
    ▼
State-updater reads state-index.yaml, then loads affected entries
    │
    ▼
Produces THREE outputs:
  1. Extraction report — what was found, direct vs propagated, high-risk
     items at the top, sourced by topic + short quote
  2. Structured diff — file changes including state-index.yaml update,
     each change approvable individually
  3. Feedback.yaml draft — finalized after PM review
    │
    ▼
Human reviews extraction report first, then diff with line-item approval
    │
    ├── Approved → git commit (state + index together)
    │       │
    │       ▼
    │   Coherence check runs async in the background
    │       │
    │       ├── Clean → done
    │       └── Flags issue → emits report for PM's next session
    │
    └── Rejected / needs refinement → human gives context, LLM re-proposes
                                       (multiple cycles are normal)
```

### Rules for the core loop

1. **Never edit files in `generated/`.** Fix state, regenerate.
2. **Humans normally don't edit canonical entries directly.** The LLM does it via the state-updater because the LLM sees the whole project via the index and catches propagation. Direct hand-edits are a rare escape hatch — fine when they happen, but expect to tell the LLM what to change.
3. **Every change appends to the entry's provenance.** Provenance is a list, not a field.
4. **Human approval is mandatory.** No auto-commit.
5. **Line-item approval is supported.** Accept some changes, reject others, in one pass.
6. **Iterative refinement is normal.** "Item 3 is wrong because X" → state-updater re-proposes. Cycles are healthy.
7. **Commit messages are meaningful.** Format: `<ID>: <change> per <source>`. For cross-domain changes, @-mention the relevant teammate.
8. **Anyone can approve.** There is no ownership hierarchy.
9. **Pull before proposing.** `git pull` first so sequential IDs are assigned against the latest state.

---

## 5. The Four Update Cases

Every proposed change is classified into one of four cases. The PM sees the classification in the extraction report.

**Case 1 — Addition.** New information that doesn't conflict with existing state. Most updates fall here.

*Example:* Client mentions a role you didn't know existed → create a new `roles/` entry.

**Case 2 — Refinement.** Additional detail that tightens or clarifies an existing entry without contradicting it.

*Example:* Meeting 1, client says apartment count should accept any number. Meeting 3, client clarifies "nothing above 10,000." R001's rationale and test-scenarios are extended. Same ID, more precise. New provenance line.

**Case 3 — Change of mind.** New information that contradicts existing state because the client (or team) has genuinely changed direction.

*Example:* Meeting 2 said investors manage properties directly. Meeting 5 introduces a property-manager role that handles day-to-day, with investors only seeing dashboards. F003's role access is rewritten.

*Handling:* Entry is overwritten in place. Git preserves history. Provenance explains the change. Commit message is explicit: `F003: removed day-to-day management per client change-of-mind 2026-05-20`.

**Case 4 — Correction.** The old entry was never correct. Transcription error, misheard statement, misinterpretation.

*Example:* Voice agent transcript said "weekly rent collection." PM realizes the client actually said "monthly."

*Handling:* Same mechanism as Case 3. Commit message calls it a correction: `R003: corrected rent frequency from weekly to monthly — transcription error, confirmed 2026-04-22`.

The difference between Case 3 and Case 4 is the story, not the mechanism. Case 3 says "client changed direction." Case 4 says "we had it wrong from the start." Provenance and commit message must make clear which.

**Why no supersession (no ID-preservation).** An earlier design considered assigning new IDs (F003 → F018) and marking the old "superseded." Rejected because git already preserves the change log, many entries reference F003 and rewriting all references on every change is painful, and the discipline cost outweighs the benefit at Superstate's scale.

---

## 6. Schema — Entry Types and Structure

Thirteen entry types. Each type is a folder with files of a specific structure. IDs follow **one letter + three digits** (`F001`, `R001`, `K001`). IDs are sequential within a type and never reused.

| Entry Type | Format | ID Prefix | Purpose |
|---|---|---|---|
| `project.yaml` | YAML | — (project slug) | Top-level metadata, one per project |
| `roles/` | YAML | — (slug) | User roles and personas |
| `entities/` | YAML | — (slug) | Data entities and their fields |
| `features/` | YAML | `F` | Discrete product features |
| `flows/` | YAML | — (slug) | User journeys across features |
| `rules/` | YAML | `R` | Business rules and constraints |
| `integrations/` | YAML | — (slug) | Third-party services |
| `sources/` | YAML | — (slug) | External document registry (links, never files) |
| `decisions/` | Markdown + frontmatter | `D` | Architecture/product decisions |
| `questions/` | Markdown + frontmatter | `Q` | Open questions to resolve |
| `feedback/` | YAML + attachments folder | — (date-slug) | Raw feedback sessions |
| `risks/` | Markdown + frontmatter | `K` | Known risks |
| `stakeholders/` | Markdown + frontmatter | `S` | People at the client who matter |

Roles, entities, flows, integrations, and sources use slug-based IDs because they're identified by name. Features, rules, decisions, questions, and risks use letter+digit IDs because they accumulate and need stable short references.

---

## 7. Folder Layout

```
projects/<project-slug>/
│
├── CLAUDE.md                             # repo-level instructions to Claude
├── README.md                             # human-readable repo intro
│
├── project.yaml                          # top-level project metadata
├── state-index.yaml                      # maintained by state-updater (§8.12)
│
├── roles/                                # one file per user role
├── entities/                             # one file per data entity
├── features/                             # one file per feature
├── flows/                                # one file per user journey
├── rules/                                # one file per business rule
├── integrations/                         # one file per external service
├── decisions/                            # one file per decision (markdown)
├── questions/                            # one file per open question (markdown)
├── feedback/                             # one file per feedback session
│   └── attachments/<session>/            # transcripts (+ language variants)
├── risks/                                # one file per known risk (markdown)
│
├── .claude/
│   ├── generators/                       # prompts that generate views
│   │   ├── generate-build-brief.md
│   │   ├── generate-backend-plan.md
│   │   └── generate-test-plan.md
│   ├── skills/
│   │   ├── state-updater.md              # the authoritative state-updater prompt
│   │   ├── extraction-report.md
│   │   ├── readiness-check.md
│   │   ├── coherence-check.md            # runs on every commit
│   │   ├── structural-integrity-check.md
│   │   ├── drift-detector.md
│   │   └── pattern-library-search.md
│   └── schema-version.yaml
│
└── generated/
    ├── build-brief.md                    # on demand
    ├── backend-plan.md                   # on demand
    └── test-plan.md                      # on demand
```

**Key notes:**

- **Transcripts only, no raw media.** Audio/video is transcribed externally, the source media is discarded, only transcripts are committed. Keeps repo size manageable, avoids Git LFS.
- **Source material is kept verbatim** in `feedback/attachments/` (with language suffixes if a translation exists alongside the original). Skills process in the repo's declared `language` and never translate or "clean" mixed phrases.
- **`CLAUDE.md` at repo root** is read automatically by Claude Code and Cowork.
- **`state-index.yaml` is maintained by the state-updater** as part of every diff. No separate rebuilder.
- **`generated/` has three files.** No PRD, no app-flow, no handoff.

---

## 8. Entry Types — Full Specification

**The canonical format for every entry type — and for `state-index.yaml` — is
[`docs/schema.md`](schema.md).** That document carries the annotated skeleton,
the required fields, and the controlled vocabularies, and it updates in every
repo with each template pull. This section no longer repeats those field-level
specs (parallel copies only go stale); it explains *why* each type exists and
how the types relate. Trust labels (`confidence`, `asserted-by`, `claim-type`,
`scope`, `re-verify-after`) and, in company-brain mode, `visibility` may appear
on any entry — see `docs/schema.md` §1 and CLAUDE.md.

**`project.yaml`** — one per repo. Terminal state is `closed`, with `outcome`
recording delivered vs lost; lost projects are still archived and feed the
pattern library (`archived` is a filesystem location, not a status).
`lessons-learned` is proposed by Claude at close. The `commercial` block
references `stakeholders/` IDs, and the state-updater keeps the two in sync
(project-state mode only). `mode` and `language` are set at first-run; absent
`mode` = `project-state`, absent `language` = `en`.

**`roles/`** — user roles and their representative personas (distinct from
`stakeholders/`, which are named real humans). Target 3–5 personas per role. A
persona built from real source material is `confidence: asserted` and carries at
least one `quotes` entry; one proposed without source material is
`confidence: derived` and must be PM-validated before it is treated as canonical
(the readiness check warns if a role has only `derived` personas). The
`inferred` field is removed in v0.7 — skills read a legacy `inferred` as an alias
(`true` → `derived`, `false` → `asserted`) and never write it again.
`test-implications` is the bridge from a persona to the test plan generator.

**`entities/`** — data entities and their fields. `fictional-in-prototype` flips
to `false` when an entity is promoted to a real backend shape (field types
tightened, constraints verified against rules, related features reviewed,
backend plan regenerated).

**`features/`** — discrete product features. The feature→flow relationship is
one-way: features carry no `related-flows` field; the index derives the reverse
lookup.

**`flows/`** — user journeys, critical for testing because the test plan walks
them to derive E2E scenarios. A flow missing `preconditions`, `expected-ui`,
`failure-modes`, or `test-persona-hints` produces a weaker test plan; the
readiness check flags these.

**`rules/`** — business rules, the primary source of test scenarios and the
primary defense against logic gaps.

**`integrations/`** — third-party services, referenced by name. **Never store
credentials** (API keys, webhook secrets, OAuth tokens) in an integration entry
or anywhere in the repo; they live in keychains, gitignored env files, or secret
managers.

**`sources/`** — registry of external documents: descriptions and links, **never
the files themselves**. Slug IDs (like integrations; `S###` belongs to
stakeholders). Status vocabulary is `active | unavailable | superseded`.
Referencing a source is an ordinary typed reference
(`references: {sources: [<slug>]}`).

**`decisions/`** — ADR-style markdown. Obsoleting a decision sets
`status: obsolete` and appends a dated provenance note explaining the
replacement; the entry is never deleted.

**`questions/`** — open questions. Answering one is a state event: feed the
answer to the state-updater, which sets `status: answered`, fills `answered` and
`answer-summary`, and propagates to entries that reference the question by
structured ID. `raised-by` uses a controlled vocabulary: team members by first
name/handle, AI agents by fixed label (`voice-agent`, `state-updater`,
`coding-agent`, `testing-agent`), the client generically as `client`.

**`feedback/`** — the immutable record of any raw ingested input (transcripts,
memos, emails, research). Written once after PM review and never edited; if
something is missed, create a new `internal-decision` entry that references it.
Write-once lifecycle: raw files land in `feedback/attachments/<date-slug>/`; the
state-updater drafts the entry alongside the diff and index patch; the PM
reviews line-item; the approved entry, the canonical changes, and the index
patch commit together. Notable types include `internal-decision`, `research`,
`ownership-change`, and `test-finding`.

**`risks/`** — known risks. The risk `severity` scale is independent from feature
`priority` and rule `severity`; the three deliberately do not map to each other.

**`stakeholders/`** — named real humans at the client who matter to the project
(in a company-brain, the company's own people and partners). Distinct from
`roles/` and never merged with them, though a stakeholder may inform a persona.
Boolean flags (`is-decision-maker`, `is-economic-buyer`, `is-champion`,
`is-interviewee`, `is-user`, `is-blocker`) can combine; a small-company founder
is often the first four at once. Created during discovery as people get named —
the state-updater surfaces authority hints ("I'd need to check with X", "Y
controls the budget") as candidates. In company-brain mode, stakeholder entries
default to `visibility: restricted`.

**`state-index.yaml`** — the pointer map the state-updater reads first on every
run to decide what to load. Per entry it holds `id`, `type`, `path`, `title`,
`status`, `references`, and `referenced-by`, plus `priority`/`severity` where the
type carries them, `blocks-phase` for questions, `confidence` on every entry,
`re-verify-after` when set, and `visibility` in brain mode. It does NOT hold
prose descriptions, full field lists, provenance, or acceptance/test detail —
those stay in the entry files. Cross-references are populated from structured
fields and frontmatter only; prose mentions never appear in `referenced-by`
(this is the definition of a "direct reference" for propagation). The
semantic-link key pairs `contradicts`/`contradicted-by` and
`derived-from`/`derives` live inside the `references`/`referenced-by` maps.

**The state-updater never rewrites the whole index.** It emits only the full
entry blocks it touched (keyed by `id`) plus blocks for new entries; the
deterministic merge script `scripts/merge-index-patch.py` (no LLM) swaps them in
by id and refreshes the header timestamp, so entries it did not emit cannot be
corrupted. On a fresh repo the index ships as an empty header (`entries: []`). If the index
is ever corrupted, delete it and run the state-updater on any input — it rebuilds
by emitting a patch that includes the index header plus one block per entry.

---

## 9. Rules for Working with State

These rules are what makes the system work.

1. **Never edit files in `generated/`.** Fix state, regenerate.

2. **Humans normally don't edit canonical entries directly.** The LLM does it via the state-updater because it sees the whole project via the index and handles propagation. Direct hand-edits are a rare escape hatch.

3. **Always append to provenance when an entry is created or modified.** Provenance accumulates; it is never rewritten. An entry without provenance is a bug.

4. **Never reuse an ID.** Rejected features, obsolete questions — their IDs stay reserved forever.

5. **One concept per file.**

6. **Reference by ID.** Inside YAML, use raw IDs (`F003`, `R001`). Inside markdown, use links: `[F003](../features/F003-portfolio-dashboard.yaml)`. Grep-friendly and clickable.

7. **Commit to git with meaningful messages.** `<ID>: <change> per <source>`. For cross-domain changes, @-mention the relevant teammate.

8. **When in doubt, add a `questions/` entry.** Uncertainty is a first-class state.

9. **Feedback entries are immutable after PM review.** If post-review something was missed, create a new `internal-decision` feedback entry, don't edit the old one.

10. **Anyone can approve a diff.** Each project has a nominal owner for continuity, but approval is not gated.

11. **Post-meeting and internal decisions are their own events.** Team decisions outside client interactions become `internal-decision` feedback entries.

12. **No secrets or credentials in the repo.** API keys, passwords, webhook secrets, OAuth tokens must never be committed. Transcripts must be scrubbed of credentials before being placed in `feedback/attachments/`. The state-updater flags suspected credentials in the extraction report and refuses to include them in diffs.

13. **Pull before running the state-updater.** Get the latest IDs.

14. **Language is per-repo.** `project.yaml`'s `language` declares the primary content language (absent = `en`). Structure stays English — schema keys, IDs, statuses, controlled vocabularies; content is in the declared language, with quotes and domain terms kept verbatim. Keep non-English source material (and any translation) in `feedback/attachments/` with language suffixes.

15. **Transcripts only, no raw media.** Audio and video are transcribed externally and discarded. Only transcripts commit.

16. **Timestamp precision.** Human-authored dates use `YYYY-MM-DD`. Machine-generated timestamps use full ISO 8601 (`YYYY-MM-DDTHH:MM:SSZ`).

17. **Rejected, deferred, and obsolete entries stay in state forever.** They are never deleted but are deprioritized: the index tags them, generators skip them by default, readiness check ignores them.

---

## 10. The State-Updater — How It Works

The state-updater is the single most important artifact in the system. Everything else can be mediocre and the system still works; if the state-updater is mediocre, the system silently rots.

The skill file `.claude/skills/state-updater.md` is the authoritative prompt. This section describes its behavior.

### Inputs and outputs

**Given:**
- The new input (transcript, memo, dev note, question answer, etc.)
- `state-index.yaml` — the map of every entry
- On-demand: specific entry files loaded based on what the input touches

**Produces:**
- An extraction report (human-readable summary with high-risk items at the top, direct and propagated changes separated)
- A structured diff covering every directly-affected entry, every one-hop propagation target, AND the `state-index.yaml` changes (emitted as entry-block patches; see the state-updater skill) — with line-item approval
- A draft `feedback/<date>-<slug>.yaml` for this input

### Index-based state reading

The state-updater never blindly loads every file. It works in phases:

1. **Load `state-index.yaml`.** Small — a few hundred lines even for a mature project.
2. **Identify directly-affected entries.** What does the input explicitly concern?
3. **Load directly-affected entries deeply.** Read the specific files fully.
4. **Identify propagation targets.** For each directly-affected entry, find entries that reference it — *using the index's `referenced-by` field*. This is bounded to one hop.
5. **Load propagation targets deeply.** Read those files too.
6. **Propose the diff.** Every directly-affected entry, every one-hop propagation target, and the index — index changes emitted as entry-block patches (see §8). Each change marked `direct` or `propagated`.

### What "directly affected" means

An entry is directly affected if:
- It is named or ID-referenced in the input, OR
- The input explicitly concerns a behavior the entry defines, OR
- The state-updater's first-pass extraction produces a change targeting it

When uncertain, the state-updater flags for PM review rather than silently including or excluding.

### Bounded propagation

Propagation is limited to one hop of direct references from the `referenced-by` field of the index. The state-updater does NOT perform transitive closure. This makes each diff's scope predictable and keeps the PM's review burden manageable.

If a multi-hop consequence is actually needed (rare), it surfaces naturally through subsequent inputs — the PM notices after the diff lands and feeds a short memo back to the state-updater.

**Prose mentions don't trigger propagation.** A decision document that says "this relates to F003 as discussed earlier" is not treated as a reference. Only structured YAML fields and markdown frontmatter count. This prevents casual mentions from dragging unrelated entries into every diff.

### The extraction report

The PM reads this first, against their memory of the meeting.

```
Extraction report — 2026-04-22-prototype-review

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
HIGH-RISK ITEMS (read these first)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
- Item 5: Case 3 (change-of-mind) on R001 — rewrites a critical rule
- Item 7: Conflict with existing state — classified as Case 4 (correction)
- Credential warning: possible API key in transcript near the Stripe
  discussion — NOT included in diff; confirm redaction

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
TOPICS COVERED IN INPUT
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
- Building creation flow: 4 items extracted
- Apartment count input: 2 items extracted
- Property manager role: 3 items extracted
- Tenant self-service (mentioned in passing): 0 items extracted
  → PM: confirm intentional skip
- Pricing discussion: 0 items extracted (out of scope for state)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
DIRECT CHANGES
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
1. F002: add property-manager to roles
   Case: refinement
   Source: property manager scope — "they handle day-to-day,
   not the investors"

2. [new] F015: Property manager dashboard (status: proposed)
   Case: addition
   Source: new PM dashboard — "PM needs their own view
   with only their buildings"

3. [new] Q012: Data scope for PM dashboard
   Case: addition
   Source: data scope question — "not sure if they should see
   tenant financials"

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
PROPAGATED CHANGES (each approvable individually)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
4. F008: add property-manager to roles
   Propagated from: change 1 (F002 gained property-manager)
   Reason: F008 references F002 as a prerequisite; may inherit roles.
   PM attention recommended: does F008 really need PM access?

5. property-manager.yaml: create new role file
   Propagated from: change 1 (new role referenced)
   Reason: roles referenced in features must exist as role files.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
ITEMS I CHOSE NOT TO PROPOSE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
- Tenant self-service portal (client said "maybe later")
- Pricing change (out of scope — commercial, not state)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
PROPAGATION SUMMARY
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Direct changes: 3
Propagated changes: 2
state-index.yaml: will be updated to reflect the above
Total files touched in diff: 6
```

**Sourcing format: topic + short quote.** Each item cites the topic it came from and includes a 5-10-word direct quote from the source for grounding. This anchors the PM's memory without being a quote-mining exercise.

### The structured diff

Standard file-change format — add, modify, delete — file by file. Each proposed change cites the item number from the extraction report so the PM can trace it.

The diff includes every directly-affected entry, every one-hop propagation target, AND the `state-index.yaml` changes — emitted as entry-block patches and merged by `scripts/merge-index-patch.py` (never a full-file rewrite).

### Iterative refinement

The PM can:

- Accept all direct changes, reject one propagated change that's wrong.
- Reject the whole proposal and tell the state-updater what's wrong ("you missed that item 4 is Case 3 — the client reversed their earlier position"). State-updater re-proposes with that context.
- Ask for clarification on a specific item.

Multiple cycles are expected and healthy.

### PM review UX — starting default

The state-updater presents the extraction report inline in chat. The PM responds conversationally ("reject item 4, approve the rest"). Once the PM is satisfied with the extraction, Claude offers to show the structured diff. Once the diff is approved, feedback.yaml is finalized and everything commits together.

This is a starting default. The team will adjust as real usage reveals what's cumbersome.

### What the state-updater must never do

- **Never auto-commit.** Human approval is always required.
- **Never silently merge conflicts.** Case 3 and Case 4 must be flagged explicitly.
- **Never fabricate provenance.** Every provenance line must cite an actual source.
- **Never edit feedback entries.** Feedback is immutable after processing.
- **Never propose a change without classifying it** as one of the four cases.
- **Never include a suspected credential in the diff.** Flag it in the extraction report and stop.
- **Never exceed one hop of propagation.** If a deeper consequence is needed, let it surface in a subsequent event.

### Pathological input handling

- **Empty or near-empty input:** propose no changes, return an extraction report saying "no extractable content."
- **Input doesn't mention the project:** ask the PM to confirm.
- **Input contradicts many entries at once:** produce the diff but flag it as high-risk; recommend careful review.
- **Input is partial:** process what exists, flag that it appears truncated.
- **Input contains credentials:** flag in the report, refuse to include in diff.

### Voice agent outputs

Voice agent discovery interviews (and any other agent producing state-relevant content) ALWAYS flow through the state-updater, regardless of output format. Structured output from a voice agent is just a richer input; it does not bypass classification, conflict detection, or human review.

### Coherence check runs after every commit

After the state-updater commits, a coherence check runs asynchronously in the background. It reads the index and spot-checks entries for contradictions the state-updater's one-hop scope may have missed. If it finds an issue, it emits a short report that the PM sees in their next session. This is the safety net for silent drift.

The live `.claude/skills/coherence-check.md` is the authoritative coherence-check skill.

### Rule-to-rule conflict detection

Two layers:
- **State-updater** catches conflicts *within its one-hop scope*. If it's editing R001 and R014 is a direct reference target, it sees both and flags incompatibilities in the extraction report.
- **Coherence check** catches *global* rule conflicts — rules that don't reference each other but contradict semantically.

This is a natural division: state-updater = local, coherence check = global.

### Example invocation

A team member says:

> "New feedback from the prototype review meeting yesterday. Transcript is at `feedback/attachments/2026-04-22-prototype-review/transcript.md`. Context: after the meeting we decided internally not to pursue the tenant self-service portal. Process it."

Claude:

1. Pulls latest from git.
2. Reads `state-index.yaml`.
3. Reads the transcript.
4. Identifies directly-affected entries and loads them.
5. Identifies one-hop propagation targets and loads them.
6. Produces extraction report with high-risk items at the top.
7. Produces structured diff (including index update) with line-item approval.
8. Produces draft feedback.yaml.
9. Presents extraction report inline. PM responds. Iterates if needed. Claude commits.
10. Coherence check runs async. If clean, done. If issue, report surfaces next time.

---

## 11. Generators — What They Are and How They Work

Generators are markdown files at `.claude/generators/`. Each is a prompt that instructs Claude to read current state and produce a specific document.

### The three generators

| Generator | Consumer | Trigger | Output |
|---|---|---|---|
| **Build brief** | Prototype coding agent | On demand at Phase 2/3 start; regenerated after major feedback cycles | `generated/build-brief.md` |
| **Backend plan** | Backend coding agent | On demand at Phase 5 start; regenerated after dev decisions | `generated/backend-plan.md` |
| **Test plan** | Testing agents (all three layers) | On demand at Phase 7 start; regenerated end-of-day or when 3+ test findings accumulate | `generated/test-plan.md` |

**No PRD generator, no app-flow, no handoff generator.** Coding agents read state directly for anything not covered by a generated view.

### Invocation protocol

- **Triggered manually** by the PM or a developer. "Claude, regenerate the build brief."
- **Output written to `generated/`**, committed as a separate commit with message `build-brief: regenerated from state as of <commit-sha>`.
- **If regeneration produces only trivial changes** (reformatting, order shuffles with no semantic change), the diff is committed anyway so the git history records that regeneration happened. Trivial regenerations are cheap.
- **If regeneration produces a large diff with no state change**, that is a generator bug. Report it.

### On-demand only

There is no git hook that auto-regenerates. Regeneration costs LLM time and tokens; running it on every state commit is wasteful when the view isn't being read.

### Generators skip deprioritized entries by default

Features with `status: rejected | deferred` are excluded from the build brief. Obsolete decisions don't appear in the backend plan. Closed risks don't feature in the test plan. A generator can be invoked with a flag to include deprioritized entries if needed, but this is the exception.

### What the build brief generator must produce

The build brief is the most important generator because it prevents the prototype structural mess.

1. **Page inventory** — every page with URL path.
2. **Role access matrix** — which roles see which pages.
3. **Shared page declarations** — pages shared across roles (same page, different permissions).
4. **Shared component inventory** — components used by more than one page, declared once.
5. **Data shape declarations** — what data each page displays and accepts, even if fictional.
6. **Rule enforcement points** — which rules must be enforced where.
7. **Routing map** — how pages connect.
8. **State backlink conventions** — every generated code file must include header comments:
   ```
   // Generated from: F001, F002
   // Enforces: R001
   // Part of flow: add-first-building
   ```
   This makes code traceable back to state and makes the drift detector possible.

### Generator determinism

Strict section ordering and templates. Regenerating with unchanged state produces near-identical output. Small stochastic prose variation is tolerated; structural drift is not.

---

## 12. How State Drives Testing

This is the section that ties Project State to the team's current unsolved problem: E2E testing that catches logic gaps without manual enumeration.

### The core idea

The testing agent doesn't need manual instructions. It reads the test plan, which is generated from state. The test plan specifies, exhaustively:

- **What must work** — every flow's happy path, derived from `flows/`
- **What must fail gracefully** — every flow's failure modes, derived from `flows/`
- **What rules must hold** — every rule's test scenarios, derived from `rules/`
- **Where to probe for logic gaps** — every rule's `logic-gap-probes`
- **What edge cases to try** — every feature's `edge-cases`
- **What personas to embody** — every flow's `test-persona-hints`

The test plan is comprehensive by construction.

### The three testing layers

**Layer 1 — Scripted scenarios (Playwright).** Deterministic tests of specific paths.

Source: `flows/` steps → Playwright scenarios (one per flow). `rules/` test-scenarios → Playwright assertions (one per scenario, covering accept and reject).

Generator behavior: emits a table of Playwright-test-name → source-state-entry, so each test has a state backlink. When a test fails, the output points to the state entry it enforces.

**Layer 2 — Persona exploration.** An AI agent embodies a realistic user persona and uses the product naturally.

Source: `flows/` `test-persona-hints` + `roles/` descriptions, goals, pain-points → persona definitions. `features/` `edge-cases` → scenarios the persona is told to try.

Generator behavior: emits one or more persona agents per role with suggested action scripts. The agent has freedom to deviate (that's the point) but starts from state-derived guidance.

**Layer 3 — Boundary / negative testing.** An agent whose explicit job is to find edge cases that break the product.

Source: `rules/` `logic-gap-probes` → aggressive probes. `entities/` field types + constraints → type-violation attempts. `flows/` `failure-modes` → confirmations that failure modes actually fail gracefully.

Generator behavior: aggregates all `logic-gap-probes` into a prioritized list, emphasizing rules with `severity: critical`.

### The apartment dropdown, formalized

Canonical example of catching a logic gap:

In state:
- R001 says "apartment count must accept any positive integer."
- R001 test-scenarios includes `input: 28, category: typical-non-round, expected: accepted`.
- R001 logic-gap-probes says "probe very large numbers, numbers with commas or decimals, whitespace, paste-from-spreadsheet scenarios."

When the test plan generates:
- Layer 1 emits a Playwright test: "enter 28 into apartment count field, expect success."
- Layer 3 emits probes: "try 1, 2, 3, 28, 47, 99, 147, 999, 10000; try '28,000'; try ' 28 ' with spaces; try pasting from a spreadsheet cell."

If the prototype has a dropdown limited to 10/20/30, Layer 1's "28 accepted" test fails immediately.

### Test plan regeneration cadence

When testing surfaces bugs, the test plan regenerates **end-of-day or when 3+ test findings have accumulated**, not after every single finding. Avoids thrash.

When regeneration happens:
1. New/refined rules and edge cases are in state (from `test-finding` feedback entries).
2. Test plan regenerates from updated state.
3. Generated tests in `generated/tests/` are disposable — old ones are replaced wholesale.

### Feeding test findings back into state

When testing finds a bug that represents a specification gap (not a code bug but state being wrong or incomplete):

1. The bug becomes state input via a `test-finding` feedback entry.
2. State updates — new rule added, existing rule refined, new edge case captured.
3. The old test (which was derived from wrong state) is now invalid and discarded.
4. Test plan regenerates, producing new tests.

Paired with the pattern library (§20), a bug found in project 5 produces a rule that can be proposed for project 11.

---

## 13. The Code-State Boundary

During prototype iteration, manual code edits will happen. When must they round-trip through state? Rule differs by phase.

### Early phase (discovery, spec, initial prototype build)

**Option B applies: behavioral changes go through state; cosmetic changes can live in code.**

- **Cosmetic (code-only is fine):** button positions, copy changes, color/spacing/typography, icons, visual layout tweaks that don't change what the product does.
- **Behavioral (must round-trip through state):** adding/removing fields, changing role-based access, changing rule enforcement, changing which features are on which page, changing data shapes, adding/removing pages, changing flows.

**Commit convention:** cosmetic changes get `<feature-ID> cosmetic: <change>`. Behavioral changes commit only after state is updated, citing the state change.

**Rule of thumb:** if the change could affect a test case, it's behavioral. If no test would care, it's cosmetic.

### Late phase (polish before client demo or delivery)

**Option C applies: drift detector runs, reverse-syncs changes into state.**

In the final polish, many small manual edits accumulate — micro-copy, visual refinements, layout nudges — and round-tripping each through state becomes a bottleneck. At this point:

1. Team edits code freely.
2. Before the phase gate (demo or delivery), the drift detector runs.
3. Drift detector reads current code, compares to the last state-generated version, produces a divergence report.
4. PM (with product/UX) reviews. Each change: "ignore" (cosmetic), "update state" (code reveals something state should reflect), or "revert."
5. State-updater is fed the report with the PM's decisions, proposes state updates, PM approves, build brief regenerates.

Not a backdoor for skipping state updates. A batched reverse-sync at phase gates that restores state integrity after a burst of fast iteration.

### The drift detector

`.claude/skills/drift-detector.md`:

- Reads current prototype code (or diff since a reference commit).
- Reads current build brief.
- Categorizes each divergence: cosmetic / behavioral / structural.
- Flags behavioral or structural divergences as requiring state review.
- Produces file-by-file report: what changed, what category, suggested state update.

**Triggered at phase gates, not by individuals.** Specifically at G5, G11, G15 (§19), the gate approver runs the drift detector as part of gate approval.

**Covers dev work too.** When backend developers make implementation decisions during Phase 6, the drift detector reverse-syncs dev decisions into `decisions/` entries at the phase gate.

The drift detector produces suggestions; the gate approver reviews, and the state-updater applies approved changes.

### Coding agent behavior when state has gaps

When the coding agent hits a gap, it emits a **structured question block** inline in chat:

```
STATE GAP ENCOUNTERED

Context: Implementing F008 (apartment detail page).
Gap: Build brief doesn't specify what happens when an apartment
     has no lease attached.
Options I see:
  a) Show "No lease" placeholder
  b) Hide the lease section entirely
  c) Link to "Add lease" flow
Recommendation: (a) — matches F012's empty-state pattern.
Waiting for human input.
```

Human answers inline. Agent proceeds. If the answer is substantive (implies a new rule or feature), the human runs the state-updater with the exchange as input afterward. If tactical only ("use option a"), no state entry needed.

**Exception:** pure mechanical defaults no test would care about (loading spinners, standard error toasts, routine animations) can be chosen by the agent. Same rule as Option B: if it could affect a test, it needs state first.

**The coding agent does NOT create `questions/` entries itself.** State entries are created by the state-updater on human initiation.

### Phase transition

The transition from Option B to Option C is itself a state event — a `decisions/` entry recording "entering polish phase on <date>."

---

## 14. Human Interfaces

No custom software is built. The team uses Anthropic's tools.

### CLAUDE.md — the repo-level instruction file

At the root of every Project State repo. Claude Code and Claude Cowork read it automatically.

**The authoritative CLAUDE.md is the file at the root of this template repo** — it ships to every project via the update script and is read automatically by Claude Code and Claude Cowork. This guide no longer embeds a copy (parallel copies only go stale). It covers: the 13 core rules, the trust labels, the two semantic link pairs, the two modes, schema-version and format authority, status transitions, and first-run setup.

### For developers: Claude Code

Claude Code runs in terminal or VS Code. Point at the local clone. Reads CLAUDE.md automatically.

### For PM, business, strategy, product/UX: Claude Cowork

Claude Cowork is a desktop app (requires Apple Silicon Mac, M1 or later). Non-technical people point at the local clone and interact conversationally.

### For mobile / anywhere: claude.ai with GitHub integration

Fallback for anyone not at desktop or on Windows / Intel Mac where Cowork isn't supported.

### Hardware note

Claude Cowork requires Apple Silicon Macs. Verify team hardware before committing to Cowork as the primary interface for non-devs.

---

## 15. Team Workflow — Ownership and Concurrency

### Project ownership

Each project has a `current-owner` field — the team member nominally driving the project. For continuity and visibility, not for gating.

**Ownership can change.** When a project is handed off (e.g., from business to PM to cover vacation), the handoff is a state event:

1. Outgoing owner writes a short memo: "Handing project X to Y. Status, open questions, next steps."
2. State-updater processes as feedback with `type: ownership-change`.
3. `project.yaml` updates with new `current-owner`.
4. Memo becomes the historical record.

**Ownership-change feedback is free-text-in-summary.** No special structure beyond the standard feedback schema.

### Concurrency

The team processes new client input roughly once a week per project. Concurrent updates are rare but possible.

**Convention to prevent ID collisions:**
1. Always `git pull` before invoking the state-updater.
2. State-updater assigns the next available ID based on latest state.
3. If two people commit new entries the same day, GitHub merge may produce conflicts on the index and new entry files. Resolve by pulling, re-running the state-updater on the unresolved side so it picks up the other side's new IDs, and re-committing.

**If a coding agent is mid-iteration when the PM processes new client feedback:** the client info wins. Developer pauses, pulls, resumes against new state.

Concurrency conflicts are rare enough to handle case-by-case. No locking protocol is enforced.

### Approval

Anyone can approve a diff. For cross-domain changes, @-mention the relevant teammate in the commit — visibility, not blocking. PM is the most common approver for feedback-driven updates; lead developers for backend-plan and dev-drift updates.

### Access and privacy

All project repos are private. Team's GitHub organization controls access. Sensitive client data (real names, account numbers, internal pricing) stays in transcripts where it can be grepped and redacted if necessary.

### Entry provenance vs git history

Entry `provenance` is the authoritative human-readable history — it's what the generators read. Git provides audit-level granularity. In case of conflict between the two, provenance is trusted.

---

## 16. Recovery and Rework

State can get into a bad shape: merge conflict leaves the index inconsistent, someone commits before PM review, a generated document gets hand-edited and then regenerated, an entry gets manually edited and breaks something.

**Recovery path: revert to the last known-good git commit and re-apply lost work.**

1. Identify the last commit where state was healthy (index matched entries, no manual edits, diffs had been reviewed).
2. `git reset --hard <that-commit>` locally, force-push if needed (coordinate with team — this rewrites history).
3. For every input processed since, re-run the state-updater one input at a time. PM re-approves each diff.

Slower than hand-repair, but reliable. For the team's volume (a few state events per week per project), redoing a week of updates takes a few hours. Acceptable cost for keeping state trustworthy.

**Do not hand-repair corrupted state.** The temptation is to "just fix the one broken entry." Once someone does that, Rule 2 is broken and the system slides back toward drift. Revert and redo is more expensive short-term and much cheaper long-term.

**Prevention.** The biggest single thing the team can do to avoid needing recovery is habitually use the state-updater for every change. The coherence check running on every commit catches subtle drift before it compounds.

---

## 17. Implementation Plan

*Historical record of the original build sequence, kept for context. The template now ships complete; where this plan conflicts with the shipped template, the template wins.*

### Phase 1: Foundation (Days 1–3)

**Day 1: Schema, template repo, CLAUDE.md**

1. Create `project-state-template` GitHub repo (private).
2. Set up folder structure from §7.
3. Create `project.yaml` template with placeholder values.
4. Add a `.gitkeep` to every entry folder — the template ships **zero example entries**; the format authority is `docs/schema.md`.
5. Create an empty `state-index.yaml` (header + `entries: []`).
6. Create `.claude/schema-version.yaml` with `version: "0.7"`.
7. Write `README.md`.
8. Write `CLAUDE.md` from the template in §14.

**Day 2: State-updater + extraction report**

1. Write `.claude/skills/state-updater.md` — the live skill is the authoritative prompt (Appendix A is retired).
2. Write `.claude/skills/extraction-report.md` — format and protocol for the extraction report (separated so other skills can reuse).
3. Test end-to-end: feed a short sample transcript, verify the extraction report surfaces high-risk items, topic + short quote sourcing works, and the diff includes index updates.

**Day 3: Core generator (build brief) + readiness check**

1. Write `.claude/generators/generate-build-brief.md`.
2. Write `.claude/skills/readiness-check.md` — checks state is ready for a phase gate (§19).

These three days produce the MVP: clone, seed, iterate, generate a build brief.

### Phase 2: Quality checks (Days 4–5)

**Day 4: Coherence checker**

Write `.claude/skills/coherence-check.md` — reads state and flags internal contradictions. Runs on every commit. (The live `.claude/skills/coherence-check.md` is authoritative; Appendix B is retired.)

**Day 5: Structural integrity + drift detector**

1. Write `.claude/skills/structural-integrity-check.md` — reads prototype code + build brief, flags mismatches.
2. Write `.claude/skills/drift-detector.md` — late-phase reverse-sync + dev-decision reverse-sync. Triggered at phase gates.

### Phase 3: Testing and remaining generators (Days 6–7)

**Day 6: Test plan generator**

Write `.claude/generators/generate-test-plan.md`. Layer 1 (Playwright) + Layer 2 (persona) + Layer 3 (logic-gap probes). Every test has a state backlink. Skips rejected/deferred entries.

**Day 7: Backend plan + pattern library search**

1. Write `.claude/generators/generate-backend-plan.md`.
2. Write `.claude/skills/pattern-library-search.md` — proposes rules and lessons from archived projects (§20).

### Phase 4: First real project (Day 8+)

1. Clone `project-state-template` to create new client's repo.
2. Run pattern library search if industry has prior projects.
3. Seed with existing meeting transcript. Run state-updater. PM reviews. Approves.
4. Generate build brief. Hand to coding agent.
5. Proceed through the pipeline.

---

## 18. Using Project State on a Real Project — Step by Step

### Phase 0 — Lead & Pre-Mapping

| Action | State operation |
|---|---|
| Lead arrives | Clone template repo, fill in `project.yaml` including `industry` and `current-owner` |
| Pattern library search (optional) | If industry has prior projects, run `pattern-library-search`. PM reviews proposed rules/lessons, accepts applicable ones. |
| AI deep research (optional) | Save to `feedback/attachments/<date>-research/` and process as `type: research` feedback. |
| PM reviews | Gate G1: pre-mapping validated before first client meeting |

### Phase 1 — Discovery

| Action | State operation |
|---|---|
| First client meeting (transcribed externally) | Discard audio/video. Store transcript (translated to English if needed) in `feedback/attachments/<date>-first-meeting/`. State-updater produces extraction report + diff + draft feedback.yaml. |
| AI voice agent follow-up interview | Same pattern. Voice agent output always goes through state-updater. |
| PM reviews extraction report against memory, then diff | Accepts / rejects / modifies items with line-item control. Iterates if needed. Feedback.yaml finalized with PM's decisions and committed. |
| Internal post-meeting decisions | Short memo → state-updater as `internal-decision` feedback |
| Readiness check for Phase 2 | Run `readiness-check`, fix flagged issues |

**Expected state after Phase 1:** ~3 roles, ~4 entities, ~10-15 features, ~4 flows, ~5 rules, ~8 open questions, ~2-3 feedback entries. Roughly 40 files.

### Phase 2 — Specification

| Action | State operation |
|---|---|
| Readiness check passes | State is ready to drive build |
| Generate build brief | Run generator on demand |
| AI coherence check | Runs automatically on every commit anyway |
| Product/UX reviews the brief | Issues → update state → regenerate |

### Phase 3 — Prototype Build

| Action | State operation |
|---|---|
| Coding agent reads build brief + state | Produces prototype code with state-backlink header comments |
| Gaps found during build | Coding agent emits structured question block; human answers inline |
| AI structural integrity check | Run against code + build brief |
| Product/UX hands-on review | Behavioral issues → state updates → brief regenerates → agent applies changes |
| Cosmetic changes during iteration | Code-only, per Option B (§13) |
| Gate approver runs drift detector | Gate G5 trigger |
| PM + business pre-client review | Gate G7: ready to demo |

### Phase 4 — Client Prototype Review

| Action | State operation |
|---|---|
| Present prototype to client | Record, transcribe externally, commit transcript |
| State-updater processes feedback | Extraction report + diff covering direct + one-hop propagation |
| PM reviews, approves | Git commit; coherence check runs async; build brief regenerated on demand |
| Coding agent applies targeted changes | No full rebuild |
| Loop until client approves | Each round is a new feedback entry |
| Deal signed | Update `project.yaml` status to `deal-signed` |

### Phase 5 — Backend Planning

| Action | State operation |
|---|---|
| Generate backend plan | Run generator on demand |
| Promote fictional data shapes | `fictional-in-prototype: false` on entities — see §8.3 promotion checklist |
| AI coherence check | Still running on every commit |
| Lead dev reviews | Architecture decisions → new `decisions/` entries |
| Regenerate backend plan | Reflects dev decisions |

### Phase 6 — Backend Build

| Action | State operation |
|---|---|
| Coding agent builds against backend plan | Produces backend code |
| Dev implementation choices | Accumulate in code; drift detector reverse-syncs at phase gate |
| Unit + integration tests generated from rules | Agent reads `rules/` test-scenarios |
| AI structural integrity check | Code vs backend plan |
| Dev review of critical paths | Auth, payments, data integrity |
| Gate approver runs drift detector | Gate G11; reverse-sync dev decisions into `decisions/` |

### Phase 7 — Testing

| Action | State operation |
|---|---|
| Generate test plan | Run generator on demand |
| Layer 1: Playwright scenarios | From flows + rule test-scenarios |
| Layer 2: Persona exploration | From roles + flow test-persona-hints |
| Layer 3: Logic-gap probing | From rule logic-gap-probes |
| Bugs → state | As `test-finding` feedback. Test plan regenerates end-of-day or at 3+ findings. Old tests discarded. |
| Readiness check for delivery | Run `readiness-check` |

### Phase 8 — Delivery and archival

| Action | State operation |
|---|---|
| Late-phase polish | Option C applies; drift detector at G15 |
| Delivery | Client receives running product (no documents) |
| Status → `closed`, set `outcome: delivered` | Or `outcome: lost` if the deal didn't close |
| Lessons learned | AI proposes bullets based on decisions, resolved questions, critical rules. PM reviews and edits. |
| Snapshot state | Tag git repo with delivery version |
| Move to archive folder | Remains available for pattern library searches |

---

## 19. Quality Gates in the Pipeline

Fifteen quality gates across the pipeline. Each is AI check, human review, or both.

| Gate | Phase | Type | What it catches |
|---|---|---|---|
| G1 | 0 | Human | Bad research before it contaminates state |
| G2 | 1 | AI (readiness) + Human | Misinterpreted client intent; state incomplete |
| G3 | 2 | AI (coherence) | Internal contradictions in state + build brief |
| G4 | 2 | Human (Product/UX) | Taste, real-world fit |
| G5 | 3 | AI (structural-integrity + drift) | Duplicated pages, forked components, code/state divergence |
| G6 | 3 | Human (Product/UX) | UX quality |
| G7 | 3 | Human | Ready to demo |
| G8 | 4 | Human | Misinterpreted client feedback |
| G9 | 5 | AI (coherence) | Backend plan doesn't match state |
| G10 | 5 | Human (Lead dev) | Architecture soundness |
| G11 | 6 | AI (structural-integrity + drift) | Code doesn't match plan; dev decisions not yet in state |
| G12 | 6 | Human (Devs) | Auth, payments, data safety |
| G13 | 7 | Human (light) | Test coverage looks right |
| G14 | 7 | AI + Human | Severity of findings |
| G15 | 8 | AI (drift) + Human | Late-phase drift reconciled; ready to ship |

Coherence check runs on every commit regardless of gate. Gates G3 and G9 are focused coherence-check runs at specific moments with a targeted report for the PM.

### AI-checkable readiness criteria

At gates G2, G9, G13, G15, the readiness check runs and produces a short report. Example output at G2:

```
Discovery readiness check — 2026-05-03

✅ 3 roles defined, all with provenance
✅ 4 entities defined, all with at least one field
⚠️  F007: no acceptance criteria
⚠️  F011: status is "approved" but Q009 is still open and blocks it
❌  R003: rationale is empty
✅ 5 flows cover all approved features
✅ All approved features referenced by at least one flow

(Rejected and deferred entries excluded from readiness criteria.)

Summary: 2 blocking issues, 1 warning. Not ready for Phase 2.
```

PM reviews, fixes issues (or delegates), re-runs. Gate passes when clean.

Specific criteria per gate live in `.claude/skills/readiness-check.md` and evolve with schema versions.

Principle: **AI generates, AI critiques, human approves.**

---

## 20. The Pattern Library

### What it is

Every archived project remains searchable. When starting a new project in a known industry, Claude searches the archive for applicable rules and lessons and proposes them as starting entries.

### How it works

1. **At close:** `project.yaml` has `industry` (required) and `lessons-learned`. Lessons proposed by Claude based on decisions, resolved questions, critical rules. PM reviews and edits. Typical length: 3-7 bullets.
2. **At new project kickoff:** PM invokes `pattern-library-search` with the new project's industry.
3. **Skill searches archived projects:** reads all `project.yaml` in archive, filters by matching industry, reads `rules/` and accepted `decisions/` from matches. Also reads `lessons-learned`.
4. **Proposes candidates:** rules and lessons with source breadcrumbs.
5. **PM accepts applicable entries.** Accepted rules enter the new project with fresh IDs, `lesson-from: <source-project-id>` in provenance, and empty `enforced-in-features` (rule enters as floating constraint). As features are defined later, the state-updater populates this field naturally.

Example output:

```
Pattern library search — industry: real-estate
Found 3 matching archived projects: acme-2025q3, bryce-holdings-2025q4, delta-realty-2026q1

Candidate rules:

1. Apartment count must accept any positive integer
   (from acme-2025q3, was R001 there)
   Rationale: Real buildings have non-round apartment counts.
   Severity: critical
   Used in 2 of 3 past projects. Recommended.

2. Leases cannot overlap on the same apartment
   (from bryce-holdings-2025q4, was R014 there)
   Rationale: Double-booking is a data integrity failure.
   Severity: critical
   Used in 1 of 3. Consider if this project handles leases.

Candidate lessons-learned:
- acme-2025q3: "Always test CSV import with non-English characters"
- bryce-holdings-2025q4: "Rent-collection timezones matter — store in UTC, display local"
```

### Cold start

The first 2-3 projects won't benefit from the pattern library at all. This is expected — the library is an accumulating asset. Expect payoff from project 4+.

### What "accepted decisions" means for the library

All decisions with `status: accepted` at project close are candidates. Obsolete decisions are not surfaced.

### When it runs

At project kickoff is canonical. The skill can be invoked at any point — if halfway through you realize "we've solved this before," nothing stops a re-search.

### What this is explicitly not

- Not embedding-based search.
- Not a cross-project database.
- Not a taxonomy beyond the `industry` tag.
- Not a blocker — if no prior projects exist, search returns empty and project proceeds.

### Scale

Simple grep across the archive works up to ~50 archived projects. Beyond that, a proper search index can be added without changing the interface.

### The key principle

Always archive, never delete. Lost projects still get archived — they still contain lessons.

---

## 21. Schema Versioning

This document describes schema **v0.7**.

- Breaking changes bump the major version: 0.x → 1.0
- Additive changes bump the minor version: 0.6 → 0.7
- Each project records its schema version in `.claude/schema-version.yaml`
- The first 3 projects will drive schema evolution — expected and healthy

### Changes from v0.6 to v0.7

- Added: **trust layer** — optional `confidence` (`verified | asserted | derived`,
  absent = `asserted`), `asserted-by`, `claim-type`, `scope` (absent = `global`),
  and `re-verify-after` on any entry. Only a human grants `verified`;
  de-verify-on-modify; staleness is computed at read time, never stored. The
  `inferred` field is removed (read as a legacy alias only).
- Added: **anti-laundering** core rule #13 — a non-verified claim's label travels
  with it; generation is never blocked, only nudged.
- Added: **verify-claim** and **reconciliation** skills.
- Added: **`sources/`** entry type (slug IDs) — external-document registry of
  links, never files; status `active | unavailable | superseded`.
- Added: two **semantic link** pairs in the index — `contradicts`/`contradicted-by`
  and `derived-from`/`derives`.
- Changed: the state-updater emits **index entry-block patches** merged by
  `scripts/merge-index-patch.py`, never a full-file rewrite.
- Changed: **language is per-repo** (`project.yaml` `language`); the old
  "all state is in English" rule is retired.
- Added: **company-brain mode** — `mode` flag, `visibility` mechanism, access
  model, `verifiers:`/`teams:`; documented in `docs/modes.md`.
- Changed: the template ships **zero example entries**; `docs/schema.md` is the
  format authority. Entry folders keep a `.gitkeep`.
- Added: the **readiness check** is written, with two pre-build existence checks
  (project `design.md`, code-repo `CLAUDE.md`).
- Added: generators emit a **"Gaps & confidence"** trailer; the README "About"
  section is filled after the first real input.
- Fixed: removed the leaked example stakeholder and the committed
  `.claude/settings.local.json` (now gitignored).

### Changes from v0.5 to v0.6

- Added: `representative-personas` field to `roles/` schema. 3-5 personas
  per role, each with background, technical-comfort, motivations,
  anti-goals, behavioral-tics, and test-implications. Personas are the
  bridge from `roles/` to Layer 2 testing. (§8.2)
- Added: `stakeholders/` as a new entry type (prefix `S`). Tracks named
  humans at the client organization with decision-maker, economic-buyer,
  champion, interviewee, user, and blocker flags. Distinct from roles.
  (§8.12)
- Added: `commercial` section in `project.yaml` referencing stakeholder
  IDs for decision-maker, economic-buyer, champion, blockers, and
  signing-representative. All fields optional. (§8.1)
- Added: state-updater scans for persona-source material and stakeholder
  mentions as distinct extraction categories. Rules enforce evidence-based
  flag setting. (Appendix A)
- Added: first-run setup instruction in CLAUDE.md — when the template is
  cloned, Claude customizes `project.yaml` and `README.md` for the new
  project on first interaction.
- Added: status-transitions section in CLAUDE.md covering how to
  transition questions, decisions, features, and risks through their
  status values.
- Fixed: R001 index entry incorrectly listed `apartment` in `referenced-by`.
  Only `building` references R001.
- Removed: duplicate copy of the implementation guide at repo root.
  Only `docs/implementation-guide.md` remains.
- Deferred (not in v0.6): company state repo, offer generator, contract
  generator, contract-acceptance-criteria on features. To be revisited
  after project state has been exercised on at least one real project.

### Changes from v0.4 to v0.5

- Added: full spec for `state-index.yaml` (§8.12) — now specifies fields, outgoing references, `referenced-by` reverse lookup, bootstrap behavior, size expectations.
- Added: v1 draft of the state-updater prompt (Appendix A).
- Added: coherence check runs automatically on every commit (§10).
- Added: rule-to-rule conflict detection has two explicit owners — state-updater for local, coherence check for global (§10).
- Changed: extraction report sourcing is topic + 5-10-word quote; line references dropped entirely (§10).
- Changed: project terminal state simplified — single `closed` status with separate `outcome: delivered | lost`. `archived` is a filesystem location, not a status (§8.1).
- Changed: Rule 2 softened from "humans never edit" to "humans normally don't edit, direct hand-edits are a rare escape hatch" (§9).
- Changed: direct-reference definition is now explicitly "structured YAML fields + markdown frontmatter only; prose mentions don't count" (§10, §8.12).
- Added: generator invocation protocol (§11) — who triggers, what commits, what to do on noisy regenerations.
- Added: promotion checklist for fictional → real entities (§8.3).
- Added: `fictional-in-prototype` promotion is a state event that also regenerates the backend plan.
- Added: coding agent's structured question block format (§13).
- Added: test plan regeneration cadence — end-of-day or 3+ findings (§12).
- Added: generated tests are disposable; old tests replaced wholesale on regen (§12).
- Added: 15-gate table clarifies coherence check runs every commit regardless of gate (§19).
- Added: ownership-change feedback is free-text-in-summary (§15).
- Added: entry provenance is authoritative vs git history in case of conflict (§15).
- Cut: older changelogs (v0.1→0.2, v0.2→0.3, v0.3→0.4) removed. Git history preserves them.
- Cut: repetition of "one hop, bounded, direct" — stated once in §10, referenced elsewhere.
- Cut: Section 2 and 3 merged — problem framing and solution framing are now a single section.

---

## 22. What Project State Does NOT Do

Deliberate omissions so the system stays focused:

- **No visual design specs.** Design quality comes from product/UX taste, informed by `ui-notes` hints in feature entries.
- **No API specs as separate files.** Pinned API contracts become `decisions/` entries. Backend plan generator produces API specs as part of its output.
- **No ticket tracking.** State is not Jira. Use a dedicated tool and link tickets back to state IDs.
- **No time tracking.**
- **No client-facing content (project-state mode).** Clients see the prototype and delivered product only; ad-hoc documentation if requested later. In company-brain mode the repo's content IS the product, served to the client through the visibility-enforcing interface — see `docs/modes.md`.
- **No deployment configuration.** Infrastructure, CI/CD, hosting live in the project's code repo.
- **No secrets, credentials, or PII beyond what's structurally necessary.**
- **No PRD.** Coding agents read state directly.
- **No handoff document.** Clients don't get docs at delivery.
- **No raw media.** Transcripts only.
- **No transitive propagation.** One hop from directly-affected entries.
- **No hand repair of corrupted state.** Recovery is always revert-to-known-good plus re-apply.

---

## 23. Glossary

- **Flow** — a user journey through one or more features.
- **Feature** — a discrete unit of product value.
- **Rule** — a business rule or constraint that applies across features/entities.
- **Entity** — a data entity; the schema of something the product stores.
- **Role** — a user persona.
- **Feedback entry** — the immutable record of an input that triggered state changes.
- **Generated document** — any file in `generated/` (build-brief, backend-plan, test-plan). Disposable; produced on demand from state.
- **Provenance** — the appended history on each entry showing where information came from.
- **Propagation** — the state-updater's job of finding entries that directly reference a changed entry and proposing updates. Bounded to one hop, uses structured references only.
- **Direct change** — a change to an entry the input explicitly concerns.
- **Propagated change** — a change to an entry that directly references a directly-affected entry.
- **Drift** — the gap between state and code (or between state and reality).
- **Drift detector** — the skill that reads code and state, flags divergences, proposes reverse-sync. Triggered at phase gates.
- **Extraction report** — the state-updater's human-facing summary with high-risk items at the top, direct vs propagated changes separated, topic + short quote sourcing.
- **Phase gate** — a checkpoint between phases. See §19.
- **Readiness check** — the AI check at phase gates that verifies state is ready for the next phase.
- **Coherence check** — the AI check that runs on every commit to catch contradictions the state-updater missed.
- **Index** — `state-index.yaml`, the pointer map maintained by the state-updater as part of every diff. See §8.12.
- **State-updater** — the prompt that reads input + state and proposes extraction report + diff + feedback.yaml draft. See `.claude/skills/state-updater.md`.
- **Generator** — a prompt that reads state and produces a view.
- **Closed + outcome** — project terminal state. `status: closed` means the project is over; `outcome: delivered | lost` records how it ended.
- **Trust labels** — the optional per-entry fields `confidence`, `asserted-by`, `claim-type`, `scope`, `re-verify-after`. Canonical definitions in `docs/schema.md` §1.
- **Confidence** — how much an entry is trusted: `verified` (human-confirmed) / `asserted` (recorded as said) / `derived` (AI-inferred). Absent = `asserted`. Only a human grants `verified`.
- **De-verify on modify** — any change to a `verified` entry resets it to `asserted` unless a verifier approves in the same session.
- **Stale (computed)** — an entry whose `re-verify-after` date has passed. Determined at read time; never stored as a field.
- **Anti-laundering rule** — core rule #13: a non-verified claim's label travels with it wherever it is restated.
- **verify-claim** — the skill that builds the verification to-do list from the index (computed, never stored) and routes human confirmations through the normal write path.
- **Semantic link** — a typed relationship key inside the index's `references`/`referenced-by` maps. Exactly two pairs exist: `contradicts`/`contradicted-by` and `derived-from`/`derives`.
- **Reconciliation** — the skill that resolves `contradicts` links: human picks the winner, state-updater updates the loser and clears the link.
- **Source (entry type)** — a `sources/` entry: a registry record (link + description, never the file) for an external document. Slug IDs.
- **Index patch** — the entry blocks the state-updater emits instead of rewriting `state-index.yaml`; merged deterministically by `scripts/merge-index-patch.py`.
- **Mode** — `project-state` or `company-brain`, set in `project.yaml` at first-run; skills branch on it. See `docs/modes.md`.
- **Visibility** — brain-mode access tier on every entry: `company` / `team/<slug>` / `restricted`. Absent = `restricted` (fail-closed).
- **Verifiers** — the `project.yaml` list of humans who may grant `verified` in a company-brain.

---

## Graph of Entry Relationships

```
Role ────────uses────────→ Feature
Feature ─────uses────────→ Entity
Feature ─────enforces────→ Rule
Flow ────────traverses───→ Feature (via steps)
Flow ────────enforces────→ Rule (via rules-enforced)
Feature ─────triggers────→ Integration
Decision ────affects─────→ Feature / Entity / Integration
Question ────blocks──────→ Feature / Rule / Decision
Feedback ────drives──────→ (any entry type, via provenance)
Risk ────────threatens───→ (any entry type)
Stakeholder ─informs────→ project.yaml commercial section (project-state)
(any entry) ─cites──────→ Source (via references: sources)
(any entry) ─contradicts→ (any entry)   [semantic link; written after coherence-check proposal + approval]
(any entry) ─derived-from→ (any entry)  [semantic link]
```

Semantic links are the only edges that carry meaning beyond "references"; their vocabulary is fixed at two pairs (see CLAUDE.md and `docs/schema.md` §2).

References flow in one direction. Flows reference features, but features do NOT carry a `related-flows` field. The index derives reverse lookups automatically.

Generators traverse this graph:
- Build brief: roles → features → flows → rules → entities
- Backend plan: entities → features → integrations → decisions → rules
- Test plan: flows → features → rules → edge-cases → roles

---

# Appendix A — State-Updater Prompt (retired)

The embedded v1 draft has been retired. **The authoritative state-updater prompt
is the live skill at `.claude/skills/state-updater.md`** — keeping a parallel
copy here only guaranteed it would drift. Read the skill file directly.

---

# Appendix B — Coherence Check Prompt (retired)

Likewise retired. **The authoritative coherence-check prompt is the live skill at
`.claude/skills/coherence-check.md`.**

---

## Summary

Project State replaces documents-as-truth with a structured git repo of small YAML/markdown files. Every piece of project knowledge is an atomic entry with a stable ID and provenance. Views like the build brief and test plan are generated on demand and never edited directly. Clients see only the demo and the delivered product — no documents.

Humans interact with state through Claude Code (devs) and Claude Cowork (everyone else). Changes flow through a single loop: event → human gives the input to the LLM → state-updater produces extraction report + diff + feedback.yaml draft → human reviews with line-item approval → git commit (includes index update) → coherence check runs async → affected generators run when explicitly needed.

The state-updater (`.claude/skills/state-updater.md`) is the load-bearing component. It uses `state-index.yaml` to see the whole project cheaply, then loads only directly-affected entries and their one-hop references. Propagation is bounded and explicit. The coherence check runs after every commit to catch what the state-updater's local scope missed.

The test plan generator turns state into comprehensive automated testing, including the logic-gap detection (apartment-dropdown-style bugs) that is the team's current unsolved problem.

Drift becomes structurally impossible because there is only one source of truth. Late-phase polish and dev-build implementation choices are the two exceptions, handled via the drift detector at phase gates. When state gets into a bad shape, recovery is revert-to-known-good plus re-apply.

The pattern library ensures hard-won rules from past projects don't get lost. The apartment dropdown lesson, and every lesson like it, persists across every future project in that industry.
