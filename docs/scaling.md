# Scaling — what to do when the repo grows

This doc exists so that nobody has to re-derive the scaling strategy under
pressure. It defines the failure modes of a growing repo, the four scaling
levels, and the triggers for moving between them. **Default posture: take no
action until a trigger fires.** Premature scaling infrastructure is waste.

---

## The boundary that prevents most scaling problems

**Types, never instances** (CLAUDE.md rule 14). The repo stores entity
*definitions*, business rules, decisions, and policies — never individual
records. A lender with 500,000 credits contributes *one* `entities/credit.yaml`,
the rules that govern credits, and the decisions made about them. Instance data
lives in the client's systems and is referenced via `integrations/`.

With this rule enforced, even a large company's brain converges to **hundreds
to low thousands of entries** — the size of the business's actual knowledge,
which is bounded. Meeting volume doesn't change this: a one-hour meeting
distills to 3–10 extracted items, and many meetings produce zero new canonical
entries. What grows linearly (raw transcripts) is kept out of the repo
entirely — external storage, registered as `sources/` links.

If the repo is growing fast anyway, check for instance-data leakage *before*
reaching for the levels below.

---

## The four levels

The bottleneck is `state-index.yaml`: it is read first on every state-updater
run, and each entry block costs roughly 100–150 tokens of context. The levels
exist to keep "decide what to load" cheap as the entry count grows.

### Level 1 — whole index (current)

Load all of `state-index.yaml` into context on every run. Simple,
deterministic, zero moving parts.

**Comfortable up to ~300 entries.**

### Level 2 — two-tier index

Split the index:

- A **master index** with one compact line per entry — `id`, `type`, `path`,
  `title`, `status`, `confidence` — small enough to always load.
- **Per-type (or per-team) shard files** carrying the full blocks, including
  `references` / `referenced-by`. The state-updater loads the master plus only
  the shards relevant to the input.

Still deterministic, still plain YAML in git, no new tooling beyond updating
the merge script to write shards.

**Comfortable up to low thousands of entries.**

### Level 3 — grep query

Stop loading even the master index wholesale. The state-updater *searches*
(keyword grep over the index and entry titles) for entries relevant to the
input, loads the hits and their one-hop references, and works from those.
No new infrastructure — only skill-instruction changes — but retrieval becomes
heuristic: a poorly-phrased search can miss a relevant entry, so the coherence
check matters more at this level.

**Comfortable while keyword overlap is good — typically well into the
thousands.**

### Level 4 — embeddings (semantic search)

Every entry gets an embedding vector; new input is matched by *meaning*, not
keywords ("cost of borrowing" finds the interest-rate rule). Requires real
infrastructure: an embedding model, a vector store, and a sync step keeping
vectors current with files. The reference implementation to study is GBrain
(github.com/garrytan/gbrain): hybrid vector + keyword search, with a knowledge
graph providing the largest retrieval-precision gain — note that this repo's
`references`/`referenced-by` maps already *are* that graph.

**Only needed if Level 3's keyword recall demonstrably fails. With the
types-not-instances rule enforced, most repos never get here.**

---

## Triggers

| Trigger | Action |
|---|---|
| `state-index.yaml` exceeds ~300 entries or ~50 KB | Move to Level 2 |
| Master index alone exceeds ~1,500 entries, or shard loading regularly pulls in most of the repo anyway | Move to Level 3 |
| Coherence check repeatedly finds near-duplicate entries (keyword recall failing) | Consider Level 4 |
| Repo grows fast without a matching growth in *kinds* of knowledge | Audit for instance-data leakage first — this is not a level problem |

---

## Related mechanisms (why they exist)

**Review tiers** (CLAUDE.md "Review tiers"). Human line-item review of every
change does not survive high ingest volume — five meetings a day would mean
hundreds of approvals daily, leading to rubber-stamping, which silently
defeats the trust system. Tiers route judgment calls to humans and bookkeeping
to the AI, with `approved-by: auto-policy` keeping every auto-commit auditable.
Trust labels make this safe: nothing auto-accepted ever claims more than
`asserted`.

**Fan-in threshold.** One-hop propagation bounds how *far* a change ripples,
not how many entries sit one hop away. Hub entries (core entities like
`credit`) can be referenced by hundreds of entries; a single edit to a hub
would otherwise produce hundreds of review line items. Above
`review-policy.fan-in-threshold`, spoke updates are mechanical auto-tier
re-stamps reported as a count; the hub change itself is always human-tier.

**Transcripts live outside the repo.** `feedback/` entries are immutable and
accumulate forever — that's fine while they hold only summaries and extracted
items. Raw transcripts/recordings would bloat git permanently; they go to
external storage and are registered as `sources/` links
(`raw-attachments` carries the slugs).

**Silent rot — the failure mode all of this guards against.** A growing repo
doesn't crash; it degrades. The updater misses an existing entry phrased
differently, creates a near-duplicate, contradictions accumulate, and the brain
gets quietly less trustworthy. Countermeasures: the right retrieval level
(above), the coherence check after every commit, and a periodic consolidation
pass when duplicates start appearing.

---

## Consolidation pass (run when needed, not on a schedule)

When the coherence check starts surfacing near-duplicates or the contradiction
backlog grows:

1. Run the coherence check across the full repo (not just last commit scope).
2. Merge duplicates via the state-updater as corrections (Case 4), keeping the
   older ID and obsoleting the newer.
3. Reconcile open `contradicts` links (reconciliation skill).
4. Review stale entries (`re-verify-after` in the past) with the verifiers.

All of it flows through the normal state-updater review process — consolidation
is ordinary maintenance, not a special mode.
