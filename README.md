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
3. **Drop the first input** (transcript, memo, email, research) into
   `feedback/attachments/<date-slug>/` and tell Claude to process it with the
   state-updater skill.
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
├── features/                   # Product features (F001, F002, …)
├── flows/                      # User journeys across features
├── rules/                      # Business rules and constraints (R001, R002, …)
├── integrations/               # Third-party services
├── sources/                    # External document registry (links, never files)
├── decisions/                  # Architecture/product decisions (D001, D002, …)
├── questions/                  # Open questions to resolve (Q001, Q002, …)
├── feedback/                   # Immutable raw ingested input
│   └── attachments/
├── risks/                      # Known risks (K001, K002, …)
├── stakeholders/               # Named people at the client (S001, S002, …)
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
| Feature | `F` + 3 digits | `F001`, `F042` |
| Rule | `R` + 3 digits | `R001`, `R014` |
| Decision | `D` + 3 digits | `D001`, `D007` |
| Question | `Q` + 3 digits | `Q001`, `Q012` |
| Risk | `K` + 3 digits | `K001`, `K003` |
| Stakeholder | `S` + 3 digits | `S001`, `S002` |
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
Drop transcript/memo into feedback/attachments/
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
