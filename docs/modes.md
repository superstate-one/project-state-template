# Modes — project-state and company-brain

**One template, a behavior switch.** First-run setup asks "project-state or
company-brain?" and writes `mode: project-state | company-brain` into
`project.yaml`. The files in both repo types are identical; the differences live
in the *skills*, which branch on the flag. Old repos with no `mode` are read as
`project-state`.

## The two modes

| | **project-state** | **company-brain** |
|---|---|---|
| Purpose | Knowledge about one client project, to drive a build | Permanent base context layer about the company itself |
| Lifespan | Bounded: discovery → delivered → closed → archived | Living, never archived (`status: active \| paused`) |
| Who feeds it | Superstate team | The client company |
| Entry types in active use | features, flows, rules, entities (feed the generators) | decisions, policies, stakeholders (= the company's own people/partners), sources, questions; features/flows dormant |
| project.yaml fields | Full deal set: status phases, outcome, industry, strategic-context, commercial, lessons-learned | No commercial/outcome/lessons-learned/strategic-context; adds `verifiers:` and `teams:` (the slug list behind `team/<slug>` visibility) |
| Generators | build brief, backend plan, test plan | None — the brain serves queries and agents, not build documents |
| state-updater extras | Tracks client decision-makers; syncs the commercial section | No deal tracking; **visibility mandatory on every new entry — diff rejected without it** |
| Readiness checks, phase gates, drift detector | On — they drive the pipeline | Off — no build, no code to drift |
| visibility | Unused — repo is Superstate-internal; access = GitHub access | Core mechanism (below) |
| Who verifies | Anyone on the team | The `verifiers:` list |
| Coherence check, verify-claim, reconciliation | Identical | Identical |
| Language | Defaults `en` | Mandatory first-run choice |

## Visibility (company-brain only)

Controlled vocabulary — expand only on real client demand.

| Value | Who sees it |
|---|---|
| `company` | Everyone in the client company |
| `team/<slug>` | A named team from `project.yaml`'s `teams:` list |
| `restricted` | Brain owner + verifiers only |

Stakeholder entries default to `restricted` — relationship assessments about
named people are sensitive. An absent tag is read as `restricted` (fail-closed);
since the state-updater rejects untagged new entries, an untagged entry is a bug
signal. Enforcement is deterministic code in the brain's interface, never LLM
judgment.

**The access model — stated hard, because visibility is theater without it:**
*client employees never receive direct repository access to a company-brain. All
non-admin access goes through the interface that enforces visibility. Direct
repo access is limited to the brain owner, listed verifiers, and Superstate.*

## scope vs visibility (they will be confused)

`scope` = who a claim *applies to*; `visibility` = who may *see* it. A salary
policy can apply to one team (`scope: team`) and be visible to nobody outside
the verifiers (`visibility: restricted`). The two are independent axes.

## Brain project.yaml semantics

A company-brain's `project.yaml`:

- `mode: company-brain`, `status: active | paused` (never `closed`/archived).
- `language` is a mandatory first-run choice — no default.
- Adds `verifiers:` (who may grant `verified`) and `teams:` (the slugs behind
  `team/<slug>` visibility).
- Omits the project-state deal fields: no `commercial`, `outcome`,
  `lessons-learned`, or `strategic-context`.

**Brains start clean:** a fresh clone, no project content ever migrates in, no
graduation mechanism. Every brain entry gets its `visibility` tag at creation.
