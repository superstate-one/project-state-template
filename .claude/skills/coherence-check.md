# Coherence Check Skill

You run after a state-updater commit to catch contradictions and broken
references the state-updater's one-hop scope cannot see. You are
read-only: you never edit state, you only report.

## Your inputs

- `state-index.yaml` at the repo root (your map of the project).
- The commit range to check (default: the most recent commit on the
  current branch). The PM may pass a wider range.
- Specific entries you load on demand based on what changed.

## Step by step

### Step 1 — Determine scope

List the entry files touched by the commit range. For each touched
entry, load:

1. The entry itself.
2. Every entry it `references` and every entry that `references` it
   (one-hop neighbours, via `state-index.yaml`).

For checks 1 and 4 below, you additionally need a global sweep over
all `rules/` and all `features/` — load these even if the commit did
not touch them. Other checks stay scoped to the commit's neighbourhood.

### Step 2 — Run the five checks

Run all five. Do not stop on the first failure.

#### Check 1 — Rule-to-rule conflicts (global)

Compare every pair of rules in `rules/` (skip `status: obsolete`).
Flag a pair as conflicting if:

- They constrain the same field of the same entity with incompatible
  bounds (e.g. R001 says `apartment.floor ≥ 0`, R007 says `floor ≤ -1`
  is allowed for basements without exempting R001).
- They prescribe mutually exclusive behaviours for the same trigger
  (e.g. two rules with the same `when` clause and contradictory `then`).
- One rule's `when` is a strict subset of another's and their `then`
  clauses contradict, without an explicit exception note.

Severity: **blocking** if both rules are `status: approved`;
**warning** if either is `status: proposed` or `draft`.

#### Check 2 — Orphaned references (scoped)

For each touched entry plus its one-hop neighbours:

- Every ID in a `references` field must point to a file that exists
  and is not `status: rejected | obsolete`.
- Every ID in `referenced-by` must be matched by a `references`
  entry on the other side. Mismatches are state-index drift.

Severity: **blocking** for dangling references; **warning** for
state-index drift (the state-updater should have caught this).

#### Check 3 — Status inconsistencies (scoped)

For each touched feature, decision, or question:

- A feature with `status: approved` must have zero `open-questions`
  whose target question is `status: open`.
- A feature with `status: complete` must have zero unresolved
  `open-questions` and every referenced rule must be `status: approved`.
- A question with `status: answered` must have a non-empty
  `answer-summary` and an `answered` date.
- A decision with `status: obsolete` must have a dated provenance
  note explaining what replaced it.

Severity: **blocking** for approved/complete feature violations and
malformed answered questions; **warning** for obsolete-decision
provenance gaps.

#### Check 4 — Flow / feature coverage (global)

- Every feature with `status: approved` must be referenced by at
  least one flow step (warning if zero — feature may be orphaned).
- Every flow step that references a feature must reference one whose
  status is not `rejected` (blocking).
- Every flow must reference at least one role whose file exists
  (blocking).

#### Check 5 — Provenance gaps (scoped)

For each touched entry:

- A non-empty `provenance` field is required on all entries except
  `feedback/` (which is itself the source).
- Each provenance line must have a date in `YYYY-MM-DD` form and a
  source (a feedback ID, decision ID, or short prose with attribution).
- Provenance dates must be `≤ today`.

Severity: **warning** for missing provenance on `proposed` or `draft`
entries; **blocking** on `approved` or `complete` entries.

### Step 3 — Suppress noise

Cross-reference your findings against the most recent state-updater
extraction report (if available in the commit message or the latest
`feedback/*.yaml` `extracted-items`). If the state-updater already
flagged an issue as high-risk and the PM accepted it knowingly, demote
the coherence finding to **info** with a note: "flagged by
state-updater on <date>, accepted by PM."

### Step 4 — Emit the report

Format:

```
Coherence check — <commit-sha> — <date>

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
BLOCKING  (N)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
[Check #] [IDs]  one-line description
  Detail: <what specifically conflicts and where>
  Suggested next step: <e.g. "open state-updater session to refine R007">

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
WARNINGS  (N)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
[same shape]

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
INFO  (N — already flagged by state-updater)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
[same shape]

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
SUMMARY
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Checks run: 5  |  Entries scanned: N  |  Blocking: N  Warnings: N  Info: N
```

If every check passes and nothing was demoted, emit a single line:

```
Coherence check clean — <commit-sha> — <date>
```

## Rules you never break

- You never edit state. You only report.
- You run async; you do not block commits. The report surfaces in the
  PM's next session.
- You do not re-derive findings the state-updater already surfaced —
  cross-reference and demote.
- You do not propose fixes. The state-updater is the only writer.
- You do not follow more than one hop, except for the explicitly
  global checks (1 and 4).
- You do not flag prose mentions of an ID as a structured reference.

## When the repo is in an unusual state

- **No `state-index.yaml`:** emit a single blocking finding ("state
  index missing; run state-updater to bootstrap"). Do not attempt to
  rebuild it yourself.
- **Commit range is empty:** emit `Coherence check clean — no
  changes`.
- **Many findings (>20):** truncate the body to the top 20 by
  severity and emit a tail line: "N additional findings suppressed;
  rerun with `--full` to see all."
