# Project State Template

This is the **superstate-project-template** — a versioned, machine-readable
repo structure for managing client project knowledge at Superstate.

## What this is

Project State replaces traditional documents (PRDs, spec docs, app-flow docs)
with a structured git repository of small YAML/markdown files. Each file is
one atomic piece of project knowledge: one feature, one rule, one user role,
one decision. Generated documents (build brief, backend plan, test plan) are
produced from state on demand and never edited directly.

Full rationale and system design: [`docs/implementation-guide.md`](docs/implementation-guide.md)

## How to use this template

1. **Clone this repo** to create a new client project repo.
2. **Replace the example content** in `project.yaml`, `roles/`, `entities/`,
   `features/`, `flows/`, `rules/` with entries for the real client.
   (Or delete the examples and start fresh.)
3. **Drop the first transcript** into `feedback/attachments/<date-slug>/` and
   tell Claude to process it using the state-updater skill.
4. **Generate a build brief** when you're ready to build the prototype.

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
├── decisions/                  # Architecture/product decisions (D001, D002, …)
├── questions/                  # Open questions to resolve (Q001, Q002, …)
├── feedback/                   # Immutable session records + raw transcripts
│   └── attachments/
├── risks/                      # Known risks (K001, K002, …)
│
├── .claude/
│   ├── schema-version.yaml     # Schema version: 0.5
│   ├── skills/
│   │   └── state-updater.md    # Primary skill — processes new input
│   └── generators/             # On-demand view generators
│
└── generated/                  # NEVER edit these — regenerate from state
    ├── build-brief.md
    ├── backend-plan.md
    └── test-plan.md
```

## Entry ID conventions

| Type | ID format | Example |
|---|---|---|
| Feature | `F` + 3 digits | `F001`, `F042` |
| Rule | `R` + 3 digits | `R001`, `R014` |
| Decision | `D` + 3 digits | `D001`, `D007` |
| Question | `Q` + 3 digits | `Q001`, `Q012` |
| Risk | `K` + 3 digits | `K001`, `K003` |
| Role | slug | `investor`, `property-manager` |
| Entity | slug | `building`, `apartment` |
| Flow | slug | `add-first-building` |
| Integration | slug | `stripe` |

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
- **All state is in English** — translate non-English source material first.
- **Feedback entries are immutable** after PM review.
- **No credentials in the repo** — ever.

## Schema version

This template targets schema **v0.5**. See [`docs/implementation-guide.md`](docs/implementation-guide.md)
§21 for the changelog and versioning policy.
