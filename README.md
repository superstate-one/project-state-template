# Project State Template

This is the **superstate-project-template** — a versioned, machine-readable
repo structure for managing client project knowledge at Superstate. The same
template runs in two modes: **project-state** (one client build) and
**company-brain** (a permanent context layer about a client company). See
[`docs/modes.md`](docs/modes.md).

## What this is

Project State replaces traditional documents (PRDs, spec docs, app-flow docs)
with a structured git repository of small YAML/markdown files. Each file is
one atomic piece of project knowledge: one feature, one rule, one user role,
one decision. Generated documents (build brief, backend plan, test plan) are
produced from state on demand and never edited directly.

The canonical format for every entry type is [`docs/schema.md`](docs/schema.md).
Full rationale and system design:
[`docs/implementation-guide.md`](docs/implementation-guide.md).

## How to use this template

1. **Clone this repo** to create a new client repo.
2. **Open it with Claude.** On first interaction Claude runs first-run setup —
   it asks for the project/client details, the mode (project-state or
   company-brain), and the language, then fills `project.yaml`. The template
   ships **no example entries**, so there is nothing to clear.
3. **Provide the first input** (transcript, memo, email, research) to Claude
   at run time — pasted or temporarily attached — and tell it to process it
   with the state-updater skill. Raw transcripts/recordings live in external
   storage (e.g. Drive) registered as `sources/` entries; the repo keeps only
   the feedback summary, extracted items, and source link.
4. **Generate a build brief** when you're ready to build the prototype
   (project-state mode).

## Folder layout

```
.
├── CLAUDE.md                   # Instructions for Claude (read automatically)
├── README.md                   # This file
├── project.yaml                # Top-level project metadata
├── state-index.yaml            # Maintained by state-updater; map of all entries
│
├── roles/                      # User roles and personas
├── entities/                   # Data entities and field definitions
├── features/                   # Product features (F0001, F0002, …)
├── flows/                      # User journeys across features
├── rules/                      # Business rules and constraints (R0001, R0002, …)
├── integrations/               # Third-party services
├── sources/                    # External document registry (links, never files)
├── decisions/                  # Architecture/product decisions (D0001, D0002, …)
├── questions/                  # Open questions to resolve (Q0001, Q0002, …)
├── feedback/                   # Immutable raw ingested input
│   └── attachments/
├── risks/                      # Known risks (K0001, K0002, …)
├── stakeholders/               # Named people at the client (S0001, S0002, …)
│
├── docs/                       # schema.md, modes.md, implementation-guide.md, …
├── scripts/                    # Template-owned helpers (update-from-template, …)
│
├── .claude/
│   ├── schema-version.yaml     # Schema version: 0.7 (the authority)
│   ├── skills/                 # state-updater, coherence-check, verify-claim, …
│   └── generators/             # On-demand view generators
│
└── generated/                  # NEVER edit these — regenerate from state
```

Entry folders ship empty — a `.gitkeep` keeps them in git.

## Entry ID conventions

| Type | ID format | Example |
|---|---|---|
| Feature | `F` + 4 digits | `F0001`, `F0042` |
| Rule | `R` + 4 digits | `R0001`, `R0014` |
| Decision | `D` + 4 digits | `D0001`, `D0007` |
| Question | `Q` + 4 digits | `Q0001`, `Q0012` |
| Risk | `K` + 4 digits | `K0001`, `K0003` |
| Stakeholder | `S` + 4 digits | `S0001`, `S0002` |
| Role | slug | `investor`, `property-manager` |
| Entity | slug | `building`, `apartment` |
| Flow | slug | `add-first-building` |
| Integration | slug | `stripe` |
| Source | slug | `pricing-sheet-2026` |

IDs are sequential within a type and **never reused**, even for rejected
or obsolete entries.

## The core workflow

```
Event happens (meeting, feedback, dev note, test finding)
    ↓
Provide transcript/memo to Claude (raw file → external storage, linked as sources/)
    ↓
Tell Claude: "Process this with the state-updater"
    ↓
Review extraction report → approve/reject individual changes
    ↓
Git commit (state + index together)
    ↓
Coherence check runs async in background
```

## Key rules

- **Never edit `generated/`** — fix state, regenerate.
- **Always use the state-updater** for changes — it handles propagation
  and index maintenance automatically.
- **Language is per-repo** — `project.yaml`'s `language` sets the primary
  content language (default `en`); structure stays English.
- **Feedback entries are immutable** after PM review.
- **No credentials in the repo** — ever.

## Schema version

This template targets schema **v0.7**. The single authority is
`.claude/schema-version.yaml`. See
[`docs/implementation-guide.md`](docs/implementation-guide.md) §21 for the
changelog and versioning policy.
