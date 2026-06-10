# Verify-Claim Skill

The verification to-do list. Invoke it with ten spare minutes: it shows you
everything in the repo that has not yet been human-confirmed, worst first, and
walks you through confirming, correcting, or skipping each one.

You are the assistant running this list. **You never grant `verified`
yourself** — only the human in the session does. You compute the list, present
each item, and route the human's decision through the normal write path.

## How the list is built — computed, never stored

There is no queue file. Every run, build the list fresh from
`state-index.yaml`:

1. Read `state-index.yaml` and `project.yaml` (for `mode`, and in
   company-brain mode the `verifiers:` list).
2. Select every entry whose `confidence` is **not** `verified` — i.e.
   `asserted`, `derived`, or absent (absent = `asserted`).
3. Order them:
   - **Expired first.** Any entry whose `re-verify-after` is in the past is
     stale (pure date math at read time — no `stale` field exists). These lead
     the list, including entries that were `verified` but have expired.
   - **Then by severity / criticality.** `severity: critical` before
     `important` before the rest; features and rules that many entries depend
     on (high `referenced-by` count) before leaf entries.
   - **Then everything else**, stable by id.

Present the count up front ("18 entries need verification; 3 are expired") so
the human can stop after the high-value ones.

## Walking each item

For each entry, show: id, title, current `confidence`, `asserted-by`, the
relevant content, its provenance, and (if set) its expired `re-verify-after`.
Then take the human's decision:

- **Confirm** → the content is correct. Set `confidence: verified` on the
  entry and its index block, append a provenance line
  (`verified by <name>, <date>`), and clear or refresh `re-verify-after` if the
  human sets a new one.
- **Correct** → the content is wrong. Feed the correction to the
  **state-updater** as an ordinary input; it proposes the change (classified
  change-of-mind or correction) through the normal diff. A corrected entry
  becomes `verified` only if the human confirms the corrected content in the
  same pass.
- **Skip** → leave it as-is (`asserted` / `derived`). No write.

## The single write path

Verification is an entry edit plus an index edit, and it goes through the
**same patch/commit flow as everything else** — the state-updater emits the
entry change and the index-block patch, the merge script applies the patch, and
the human's confirmation **is** the approval. A provenance line is appended on
every verification. **No second write path exists** — verify-claim never writes
state directly, never keeps a queue, never bypasses the diff.

## Who may verify

- **project-state:** anyone on the Superstate team.
- **company-brain:** only a human listed in `project.yaml`'s `verifiers:`.
  If the person running the list is not on it, present the list read-only and
  do not record any `verified` stamp.

## Rules you never break

- Never grant `verified` on your own judgement — a human decides every item.
- Never write `verified` to an entry whose content the human did not confirm.
- Never store the list to a file; it is always recomputed from the index.
- Never promote a `derived` claim to `verified` without the human reading the
  actual content first.
- In company-brain mode, never record a verification by someone not on
  `verifiers:`.
