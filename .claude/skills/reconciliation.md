# Reconciliation Skill

The partner to the coherence check. The coherence check *detects* contradictions
and (after PM approval) the state-updater writes a `contradicts` link between
the two entries. Reconciliation *resolves* them: it walks each conflicting pair,
the human picks the winner, the loser is updated through the normal flow, and
the link clears.

Detection is automatic and persisted in the index. Resolution is human and
persisted in the entry. You run the resolution; you never pick the winner.

## When to run

Run when `contradicts` links exist in `state-index.yaml` — the coherence
check's report will say so, or a `contradicts` / `contradicted-by` key appears
in any entry's index block. A `contradicts` link persists from detection until
reconciliation clears it, so the index always shows the open conflicts.

## Procedure

1. Read `state-index.yaml`; collect every `contradicts` / `contradicted-by`
   pair (each conflict appears once — don't double-count the reverse key).
2. For each pair, load both entries fully and present them side by side:
   id, title, the conflicting content, `confidence`, `asserted-by`, each
   entry's provenance and dates, and any `sources:` they cite. Surface which
   is more trusted (a `verified` entry over an `asserted` one) and which is
   newer, but **do not decide**.
3. The human picks the winner (or a new merged statement).
4. The losing entry is updated through the **state-updater's normal approval
   flow** — classified as change-of-mind or correction, overwritten in place
   (never deleted, per the overwrite principle), with a provenance line
   explaining the resolution.
5. The state-updater **clears the `contradicts` link** from both entries' index
   blocks in the same diff. The resolution lands in provenance and git history.

## Constitution

Reconciliation proposes and presents; the **state-updater is the only writer**;
the human approves every change. You never edit state directly.

## Rules you never break

- Never pick the winner yourself — the human decides every conflict.
- Never delete the losing entry. Overwrite it in place; git preserves history.
- Never clear a `contradicts` link without an actual resolution recorded in the
  winner/loser provenance.
- Never resolve more than the pair in front of you — one conflict at a time,
  each through its own reviewed diff.
- Never let a resolution silently re-grant `verified`; a corrected entry
  becomes `verified` only if a human confirms the new content (in a brain, a
  human on `verifiers:`).
