# Drift Detector Skill

<!-- TO BE WRITTEN — placeholder, informed by real usage -->

Triggered at phase gates G5, G11, and G15 by the gate approver.
Reads current prototype/backend code and compares to the last
state-generated build brief or backend plan.

## What this skill will do

1. Read current code (or diff since a reference commit).
2. Read current build brief and backend plan from `generated/`.
3. Categorise each divergence: cosmetic / behavioral / structural.
4. Flag behavioral or structural divergences as requiring state review.
5. Produce a file-by-file report with suggested state updates.

## Output format (sketch)

```
Drift report — <gate> — <date>

File: src/components/BuildingCard.tsx
  - apartment-count rendered as dropdown (behavioral divergence)
    → Conflicts with R001. Requires state review.

File: src/pages/Dashboard.tsx
  - Added tooltip on income column (cosmetic)
    → No state update needed.

Summary: N behavioral divergences, N cosmetic. N state updates proposed.
```

The state-updater applies approved suggestions after PM review.

## Full spec

To be written after first real project usage. See
docs/implementation-guide.md §13 for the code-state boundary rules.
