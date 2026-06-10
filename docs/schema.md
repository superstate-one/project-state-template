# Project State — Schema Reference

**Schema version 0.7.** This document is the **format authority** for every entry
type in a Project State or company-brain repository. When a skill needs to know
what an entry looks like — which fields exist, which are required, what the
controlled vocabularies are — it follows this document. The template ships **no
example entries**; this file replaces them. Skills must never look in an entry
folder expecting examples.

All placeholder values below (`acme-realestate`, `Jane Chen`, `S001`, etc.) are
**obviously fake**. They illustrate shape, not content. Copying them verbatim
into a real repo is a bug.

---

## 0. Conventions that apply everywhere

**IDs.** One letter + three digits for accumulating types (`F001`, `R001`,
`D001`, `Q001`, `K001`, `S001`). Slugs for name-identified types (`roles/`,
`entities/`, `flows/`, `integrations/`, `sources/`). IDs are sequential within a
type and **never reused** — a rejected `F014` keeps its number forever.

**Provenance is mandatory.** Every entry records where its content came from.
Provenance is a *list*, appended to on every change, never rewritten. An entry
with no provenance is a bug. YAML entries carry a `provenance:` list; markdown
entries carry a `## Provenance` section.

**References vs. prose.** Cross-references live in structured fields
(`roles: [investor]`, `related-rules: [R001]`) and markdown frontmatter only.
A prose sentence "this relates to F003" is **not** a reference and never appears
in the index's `referenced-by`. Only structured references drive propagation.

**Language.** Structure is always English — schema keys, IDs, statuses, folder
names, controlled vocabularies. **Content** (titles, descriptions, rationale,
quotes) is written in the repo's declared `language` (`project.yaml`). Quotes
and domain terms stay verbatim in their original language even when that differs
from the declared primary language. See CLAUDE.md rule 8.

**Timestamps.** Human-authored dates: `YYYY-MM-DD`. Machine timestamps: full ISO
8601 (`YYYY-MM-DDTHH:MM:SSZ`).

**No secrets, ever.** API keys, passwords, tokens, webhook secrets never appear
in any entry. The state-updater flags suspected credentials and refuses to
include them in a diff.

---

## 1. The trust layer — labels that may appear on any entry

Every canonical entry may carry these labels. **All are optional with safe
defaults**, which is what keeps pre-0.7 repos valid. They answer "how much do we
trust this, and who said it."

```yaml
confidence: verified | asserted | derived   # default: asserted
asserted-by: client | S001 | kaloian | voice-agent | state-updater
claim-type: fact | preference | policy | estimate
scope: global | team | person               # default: global
re-verify-after: 2026-12-01                  # optional expiry on trust
```

| Label | Question | Values & default |
|---|---|---|
| `confidence` | How much do we trust this? | `verified` (a human confirmed it) · `asserted` (someone said it, recorded as-is) · `derived` (the AI inferred it, nobody said it). **Absent = `asserted`.** |
| `asserted-by` | Who said it? | `client`, a stakeholder ID (`S001`), a team member (`kaloian`), or an AI agent (`voice-agent`, `state-updater`) |
| `claim-type` | What kind of statement? | `fact`, `preference`, `policy`, `estimate` |
| `scope` | Who does the claim apply to? | `global`, `team`, `person`. **Absent = `global`.** |
| `re-verify-after` | When does this trust expire? | a date; optional |

**Rules of the trust layer:**

- **Only a human grants `verified`.** The AI can never promote its own claims to
  `verified`. The verifying human *is* the approval; a provenance line records it
  (`verified by jane, 2026-06-10`).
- **De-verify on modify.** Any modification to a `verified` entry resets its
  `confidence` to `asserted`, and the change is flagged in the extraction report
  ("this change de-verifies F012") — *unless* a listed verifier approves the
  change in the same session, in which case it stays `verified` with a fresh
  provenance stamp. Verification applies to an entry's *current content*, never
  its history.
- **`confidence` is its own field.** It never overloads `status`.
- **"Stale" is computed, never stored.** An entry whose `re-verify-after` is in
  the past is *treated as* stale by everything that reads the index (verify-claim
  lists it first, generators flag it). Pure date math at read time — no `stale`
  field is ever written.
- **`inferred` is removed.** Personas use `confidence` like everything else: an
  AI-guessed persona is `derived`, a quote-backed one is `asserted`. Skills read
  a legacy `inferred` in old repos as an alias (`true` → `derived`, `false` →
  `asserted`) and never write it again.

**`visibility` (company-brain mode only).** In a brain, every entry also carries
who may *see* it. Mandatory on every new brain entry — the state-updater rejects
a brain diff that omits it. Unused in project-state (access = GitHub access).

```yaml
visibility: company | team/<slug> | restricted   # brain mode; absent = restricted (fail-closed)
```

| Value | Who sees it |
|---|---|
| `company` | Everyone in the client company |
| `team/<slug>` | A named team from `project.yaml`'s `teams:` list |
| `restricted` | Brain owner + listed verifiers only |

`scope` ≠ `visibility`. `scope` = who a claim *applies to*; `visibility` = who may
*see* it. A salary policy can apply to one team (`scope: team`) and be visible to
nobody outside the verifiers (`visibility: restricted`). See `docs/modes.md`.

---

## 2. Semantic links — typed relationships in the index

Beyond ordinary typed references, the index carries links that say *what a
relationship means*. They live as keys inside the existing `references` /
`referenced-by` maps (exactly like the `affects` key). The vocabulary is **only**
these two pairs — adding a new type requires a schema bump:

| Forward key | Reverse key | Meaning |
|---|---|---|
| `contradicts` | `contradicted-by` | These two entries conflict |
| `derived-from` | `derives` | This claim was inferred from that entry |

`contradicts` links are written by the state-updater after the coherence check
proposes them and a human approves; they persist until reconciliation clears
them (see the coherence-check and reconciliation skills).

---

## 3. `project.yaml` — one per repo

Top-level metadata. The shape differs slightly by `mode` (see `docs/modes.md`).

```yaml
id: acme-realestate
name: Acme Real Estate Management Platform
client: Acme Holdings
mode: project-state | company-brain        # absent = project-state
language: en                               # absent = en; brain mode: mandatory, no default
status: discovery | spec | prototype | deal-signed | building | testing | delivered | closed
                                           # brain mode: active | paused
schema-version: "0.7"                       # schema at last content write (informational; lags)
created: 2026-04-09
last-updated: 2026-04-09
current-owner: kaloian
industry: real-estate
summary: >
  One-paragraph description of what this repo is and why it exists.

# --- project-state only ---
outcome: delivered | lost | null            # set when status becomes 'closed'
strategic-context:
  client-size: small-enterprise
  deal-value-range: mid
commercial:
  # Populated during discovery. Reference stakeholders by ID. All fields
  # optional, default null/empty. Ships reset to nulls in a fresh template.
  decision-maker: null                      # stakeholder ID, or null
  economic-buyer: null                      # stakeholder ID, or null
  champion: null                            # stakeholder ID, or null
  blockers: []                              # list of stakeholder IDs
  signing-representative: null
lessons-learned: []                         # filled in when moving to 'closed'

# --- company-brain only (omit the project-state block above) ---
verifiers: [jane, kaloian]                  # who may grant `verified`
teams: [sales, engineering, finance]        # slugs behind team/<slug> visibility
```

**Required:** `id`, `name`, `client`, `status`, `schema-version`, `created`,
`current-owner`, `industry`, `summary`. In a fresh project-state repo the
`commercial` block is present with all fields null. In a brain, `verifiers` is
required and the commercial/outcome/lessons-learned/strategic-context blocks are
omitted.

**Mode & language defaults for old repos:** absent `mode` = `project-state`;
absent `language` = `en`.

**`schema-version` here is informational** — it records the schema at the last
content write and is expected to lag. The single authority is
`.claude/schema-version.yaml` (see CLAUDE.md).

---

## 4. `roles/<slug>.yaml`

User roles and their personas. Different from `stakeholders/` (named real
humans).

```yaml
id: investor
name: Real Estate Investor
description: >
  Individual or entity owning multiple buildings, focused on ROI and
  portfolio management rather than day-to-day operations.
goals:
  - Track portfolio performance at a glance
  - Understand cashflow per building
pain-points:
  - Spreadsheets break as portfolio grows
technical-skill: low | medium | high
frequency-of-use: daily | weekly | monthly | occasional
representative-personas:
  - id: persona-jane
    name: Jane Chen
    confidence: asserted        # quote-backed = asserted; AI-guessed = derived (replaces `inferred`)
    one-line-summary: Cautious 58-year-old investor, owns 4 buildings, distrusts new software
    background: >
      Multi-sentence narrative. Where they come from, what their day looks
      like, who influences their decisions. Carries most of the behavioral
      weight for testing agents.
    demographics:
      age-range: 55-65
      location: Sofia, Bulgaria
      portfolio-size: 4 buildings
      experience-level: 5 years as investor
    technical-comfort:
      level: low | medium | high
      uses: email, Excel, online banking
      avoids: mobile-only apps, auto-charge to card
      typical-failure-mode: closes the browser when something looks wrong
    motivations:
      primary: Stable retirement income
      secondary: Protect capital from inflation
      emotional: Feel competent and in control
    anti-goals:
      - Does not want to manage tenants directly
    behavioral-tics:
      - Reads every label before clicking
    success-looks-like: >
      One-paragraph description of a good session for them.
    failure-looks-like: >
      One-paragraph description of how they fail — often silent (abandonment).
    quotes:
      - source: feedback/2026-04-09-first-meeting
        quote: "5-10 word verbatim from the transcript that grounds this persona"
    test-implications:
      - Specific testing scenarios this persona drives
provenance:
  - date: 2026-04-09
    source: feedback/2026-04-09-first-meeting
    note: Client described their own workflow
```

**Required:** `id`, `name`, `description`.

**Personas:** target 3–5 per role. A persona with no `quotes` defaults to
`confidence: derived` (it was inferred without source material) and must be
validated by the PM before being treated as canonical. `test-implications` is the
bridge to the test plan generator.

---

## 5. `entities/<slug>.yaml`

```yaml
id: building
name: Building
description: A single physical property owned by an investor.
fictional-in-prototype: true
fields:
  - name: id
    type: uuid
    required: true
  - name: address
    type: string
    required: true
  - name: apartment-count
    type: integer
    required: true
    constraints: [R001]
  - name: owner
    type: reference
    references: investor
    required: true
relationships:
  - type: one-to-many
    to: apartment
  - type: many-to-one
    to: investor
provenance:
  - date: 2026-04-09
    source: feedback/2026-04-09-first-meeting
```

**Required:** `id`, `name`, `description`, `fields`.

**Field types:** `string`, `integer`, `float`, `boolean`, `date`, `datetime`,
`uuid`, `enum`, `reference`, `text`, `json`.

`fictional-in-prototype: true` flips to `false` when the entity is promoted to a
real backend shape (field types tightened, constraints verified, backend plan
regenerated).

---

## 6. `features/F<NNN>-<slug>.yaml`

```yaml
id: F002
title: Bulk import apartments into a building
status: proposed | approved | in-prototype | in-build | complete | deferred | rejected
priority: must-have | should-have | nice-to-have
description: >
  User can add many apartments to a building at once without entering
  each one manually.
roles: [investor, property-manager]
related-entities: [building, apartment]
related-rules: [R001]
acceptance-criteria:
  - User can enter any positive integer for apartment count
  - User can optionally upload a CSV for apartment details
edge-cases:
  - 28 apartments (non-round number)
  - 500+ apartments
ui-notes: >
  Optional free-text hints for the prototype builder.
backend-notes: >
  Optional free-text hints for backend considerations.
open-questions: [Q007]
confidence: asserted          # trust layer (optional; §1)
asserted-by: client
provenance:
  - date: 2026-04-09
    source: feedback/2026-04-09-first-meeting
    note: Client mentioned buildings of various sizes
```

**Required:** `id`, `title`, `status`, `description`, `roles`,
`acceptance-criteria`.

Features do **not** carry a `related-flows` field — the feature→flow relationship
is one-way; the index derives the reverse lookup.

---

## 7. `flows/<slug>.yaml`

Flows drive testing — the test plan walks flows to derive E2E scenarios.

```yaml
id: add-first-building
name: Investor adds their first building
description: >
  End-to-end journey of a new investor onboarding their first building,
  from login to seeing it on their dashboard.
role: investor
trigger: User has completed signup and is on empty dashboard
preconditions:
  - User is authenticated
  - User has zero buildings in their portfolio
steps:
  - step: 1
    action: User clicks "Add Building"
    feature: F001
    expected-ui: Building creation modal appears
  - step: 2
    action: User enters building address and apartment count
    feature: F001
    rules-enforced: [R001]
    expected-ui: Inline validation feedback on apartment count
success-criteria:
  - Building record exists with correct address and apartment count
  - Dashboard shows the new building
failure-modes:
  - User enters invalid apartment count → R001 error, step 2 blocks
test-persona-hints: >
  Realistic investor personas: cautious first-timer reading every tooltip;
  experienced user tabbing through quickly.
provenance:
  - date: 2026-04-11
    source: feedback/2026-04-11-voice-agent-interview
```

**Required:** `id`, `name`, `description`, `role`, `steps`, `success-criteria`.

Flows without `preconditions`, `expected-ui`, `failure-modes`, and
`test-persona-hints` produce weaker test plans; the readiness check flags these.

---

## 8. `rules/R<NNN>-<slug>.yaml`

Rules are the primary source of test scenarios and the primary defense against
logic gaps.

```yaml
id: R001
rule: Apartment count must accept any positive integer
rationale: >
  Real buildings have non-round apartment counts. Dropdowns or fixed lists
  always miss real-world cases.
enforced-in-features: [F001, F002]
enforced-in-entities:
  - entity: building
    field: apartment-count
test-scenarios:
  - input: 28
    expected: accepted
    category: typical-non-round
  - input: 0
    expected: rejected with clear error
    category: boundary-invalid
  - input: "twenty"
    expected: rejected
    category: type-invalid
severity: critical | important | nice-to-have
logic-gap-probes: >
  Probe: very large numbers (10000+), commas or decimals, whitespace,
  paste-from-spreadsheet scenarios.
lesson-from: acme-realestate-2025-q3     # optional — pattern library breadcrumb
provenance:
  - date: 2026-04-22
    source: feedback/2026-04-22-prototype-review
    note: Client showed real building with 28 apartments
```

**Required:** `id`, `rule`, `rationale`, `severity`.

---

## 9. `integrations/<slug>.yaml`

```yaml
id: stripe
name: Stripe
purpose: Payment processing for tenant rent collection
phase: backend
features-using: [F012, F013]
data-flows:
  - direction: outbound
    data: payment intent
  - direction: inbound
    data: webhook notification
decisions: [D004]
open-questions: [Q009]
provenance:
  - date: 2026-04-09
    source: feedback/2026-04-09-first-meeting
```

**Required:** `id`, `name`, `purpose`.

**Never store credentials.** API keys, webhook secrets, OAuth tokens live outside
the repo. State references integrations by name only.

---

## 10. `sources/<slug>.yaml`  *(new in v0.7)*

A registry of **external documents** — descriptions and links, **never the files
themselves**. One small YAML per source: what it is, where it lives, what it
covers, when last checked. Identified by slug (like integrations), because a
source is known by name — **not** `S###`, which belongs to stakeholders.

```yaml
id: pricing-sheet-2026
name: 2026 Pricing Sheet
kind: spreadsheet | document | url | dataset | contract | other
location: https://drive.google.com/file/d/PLACEHOLDER     # Drive link or URL — a pointer, never the file
covers: >
  Per-tier subscription pricing and discount bands used in the commercial model.
status: active | unavailable | superseded
last-checked: 2026-06-01
confidence: asserted          # trust layer (optional; §1)
asserted-by: client
provenance:
  - date: 2026-06-01
    source: feedback/2026-06-01-pricing-call
    note: Client shared the link during the pricing call
```

**Required:** `id`, `name`, `location`, `status`.

**Status vocabulary:** `active` (current and reachable) · `unavailable` (link
dead or access lost) · `superseded` (replaced by a newer source). The coherence
check validates references against these.

**Referencing a source** is an ordinary typed reference in the index:
`references: {sources: [pricing-sheet-2026]}` — same convention as
`features: [...]`. The folder ships empty with a `.gitkeep`; the state-updater
creates entries when external documents are mentioned.

---

## 11. `decisions/D<NNN>-<slug>.md`

ADR-style. Markdown with YAML frontmatter.

```markdown
---
id: D007
title: Use Postgres, not MongoDB
status: accepted | proposed | obsolete
date: 2026-04-15
affects: [backend]
confidence: verified           # trust layer (optional; §1)
asserted-by: kaloian
---

## Context

The data model is fundamentally relational — buildings own apartments,
apartments have leases, leases have payments.

## Decision

We will use PostgreSQL for the primary data store.

## Consequences

- Devs familiar with SQL can contribute faster.
- We lose schema flexibility, but our schema is stable.

## Provenance

- 2026-04-15: Backend planning session; lead dev proposed, team agreed.
```

**Required frontmatter:** `id`, `title`, `status`, `date`.

Obsoleting a decision: set `status: obsolete`, append a dated Provenance note
explaining what replaced it. Never delete.

---

## 12. `questions/Q<NNN>-<slug>.md`

```markdown
---
id: Q007
title: Does the investor want bulk CSV import for apartments?
status: open | answered | obsolete
raised: 2026-04-09
raised-by: voice-agent
answered: null
answer-summary: null
related-features: [F002]
blocks-phase: spec
---

## The question

During the voice agent interview the investor mentioned "uploading a
spreadsheet would be amazing" but didn't specify format or frequency.

## Why it matters

If yes, F002 needs CSV parsing logic. If no, F002 is simpler.

## What we need

Follow-up with client: confirm CSV is wanted, get sample file.
```

**Required frontmatter:** `id`, `title`, `status`, `raised`.

Answering is a state event: set `status: answered`, fill `answered` and
`answer-summary`, keep the original body intact, never delete the file.

**`raised-by` vocabulary:** team members by first name/handle (`kaloian`); AI
agents by fixed label (`voice-agent`, `state-updater`, `coding-agent`,
`testing-agent`); client generically as `client`.

---

## 13. `feedback/<date>-<slug>.yaml`

One file per ingested input. **`feedback/` holds any raw ingested input** —
transcripts, memos, emails, research. Immutable after PM review; if something is
missed, create a new `internal-decision` entry that references this one.

```yaml
id: 2026-04-22-prototype-review
date: 2026-04-22
type: prototype-review | voice-interview | live-meeting | email | async-review | internal-decision | research | ownership-change | test-finding
participants:
  - client: jane-smith
  - us: kaloian
raw-attachments: feedback/attachments/2026-04-22-prototype-review/
summary: >
  Client reviewed the prototype. Overall positive. Main concerns:
  apartment count input, property manager role scope.
extracted-items:
  - type: feature-change
    target: F002
    change: Include property manager role
    change-class: direct
    status-in-diff: accepted
  - type: new-feature
    target: F015
    change: Property manager dashboard
    change-class: direct
    status-in-diff: rejected
    rejection-reason: Out of scope for v1
status: processed
```

**Required:** `id`, `date`, `type`, `participants`, `summary`.

Feedback is **excluded from the trust-layer backfill** — it is immutable and is
itself the source of provenance. Write-once: drafted by the state-updater,
finalized after PM line-item review, committed alongside the entry and index
changes.

---

## 14. `risks/K<NNN>-<slug>.md`

```markdown
---
id: K001
title: Backend cannot match prototype data shapes without rework
status: open | mitigated | materialized | closed
severity: low | medium | high
---

## Risk

Prototype was built with fictional data shapes. Backend may need to reshape
data, which could break frontend assumptions.

## Mitigation

Phase 5 backend plan explicitly maps fictional → real data shapes.
```

**Required frontmatter:** `id`, `title`, `status`, `severity`.

Risk `severity` is independent from feature `priority` and rule `severity` — the
three scales don't map to each other. Closed risks stay in the repo (set
`status: closed`); they remain available to the pattern library.

---

## 15. `stakeholders/S<NNN>-<slug>.md`

Named real humans at the client who matter to the project — distinct from
`roles/` (product personas). In a company-brain these are the company's own
people and partners. Markdown with YAML frontmatter.

```markdown
---
id: S001
name: Jane Chen
title: Founder & CEO
company: Acme Holdings
email: jane@acme-example.com        # optional, omit if sensitive
phone: null

# Role flags — any combination can be true
is-decision-maker: true
is-economic-buyer: true
is-champion: true
is-interviewee: true
is-user: false
is-blocker: false

# Qualitative assessment
relationship-temperature: cold | cool | neutral | warm | hot
influence-on-decision: low | medium | high

# Trust + (brain mode) visibility
confidence: asserted
asserted-by: kaloian
visibility: restricted              # brain mode: stakeholders default restricted (sensitive)
---

## Background

Free-text. Who they are, how long at the company, who they report to.

## What they care about

Bullet list of priorities, values, things they bring up.

## What they worry about

Bullet list of concerns, objections, risks from their perspective.

## Quotes

- 2026-04-09: "verbatim quote" (source: feedback/2026-04-09-first-meeting)

## Provenance

- 2026-04-09: how we learned about them, which session
```

**Required frontmatter:** `id`, `name`.

One person can hold multiple flags (a small-company founder is often
decision-maker + economic-buyer + champion + interviewee at once). Stakeholders
are never merged with roles. In brain mode, stakeholder entries default
`visibility: restricted` — relationship assessments about named people are
sensitive.

---

## 16. `state-index.yaml`

The pointer map maintained by the state-updater as part of every diff. Read first
on every run to decide what to load. v0.7 adds per-entry `confidence` (and
`visibility` in brains) so verify-claim and access filtering work from the index
without opening files, plus the two semantic-link key pairs inside
`references`/`referenced-by`.

```yaml
schema-version: "0.7"
generated-at: 2026-06-10T14:22:00Z
project-id: acme-realestate
entries:

  - id: F002
    type: feature
    path: features/F002-bulk-import-apartments.yaml
    title: Bulk import apartments into a building
    status: approved
    priority: must-have
    confidence: asserted          # new in v0.7
    references:
      roles: [investor, property-manager]
      entities: [building, apartment]
      rules: [R001]
      questions: [Q007]
      sources: [pricing-sheet-2026]
      derived-from: [F001]        # semantic link (optional)
    referenced-by:
      flows: [add-first-building]
      contradicted-by: []         # semantic link (optional)

  - id: R001
    type: rule
    path: rules/R001-apartment-count-any-positive-integer.yaml
    title: Apartment count must accept any positive integer
    status: active
    severity: critical
    confidence: verified
    re-verify-after: 2026-12-01    # optional; staleness computed at read time
    references:
      entities: [building]
    referenced-by:
      features: [F001, F002]
      flows: [add-first-building]

  - id: S001
    type: stakeholder
    path: stakeholders/S001-jane-chen.md
    title: Jane Chen — Founder & CEO
    status: active
    confidence: asserted
    visibility: restricted        # brain mode only
    flags: [is-decision-maker, is-economic-buyer, is-champion, is-interviewee]
    references: {}
    referenced-by: {}
# ... one block per entry
```

**Per-entry fields:** `id`, `type`, `path`, `title`, `status`, `references`,
`referenced-by` are always present. `priority`/`severity` appear only for types
that carry them; `blocks-phase` only for questions; `confidence` on every entry;
`re-verify-after` when set; `visibility` in brain mode.

**Not in the index:** prose descriptions, full field lists, provenance history,
acceptance criteria, test scenarios — all stay in the entry file.

**Index patch mode (v0.7).** The state-updater never rewrites the whole file. It
emits only the **full blocks of the entries it touched** (keyed by `id`) plus
blocks for new entries; a deterministic merge script in `scripts/` swaps them in
by id and refreshes `generated-at`. The LLM physically cannot corrupt entries it
didn't emit. References are populated from structured fields only — prose
mentions never appear in `referenced-by`.
