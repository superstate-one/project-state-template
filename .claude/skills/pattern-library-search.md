# Pattern Library Search Skill

<!-- TO BE WRITTEN — placeholder, informed by real usage -->

Invoked at new project kickoff (or any point during the project).
Searches archived projects for rules, decisions, and lessons that
apply to the new project's industry.

## What this skill will do

1. Read all `project.yaml` files in the archive folder.
2. Filter by `industry` tag matching the new project.
3. Read `rules/` and accepted `decisions/` from matching projects.
4. Read `lessons-learned` from matching project.yaml files.
5. Propose candidates with source breadcrumbs.
6. **Translate every candidate into the target repo's language** before
   presenting (see below).

## Language — translate on propose

Archived projects are often in a different language from the new project (most
Superstate clients are Bulgarian; some projects run in English). When you
propose a candidate, render its content in the **target** repo's `language`
(from the new project's `project.yaml`; absent = `en`) — a Bulgarian rule
proposed into an English project is translated to English, and vice-versa.

Translate the prose only: rule text, rationale, and lesson wording. Structure
stays English — keys, IDs, statuses, severities. The `lesson-from:
<source-project-id>` breadcrumb preserves the untranslated origin for anyone who
wants the original.

## Output format (sketch)

```
Pattern library search — industry: <industry>
Found N matching archived projects: <id>, <id>, …

Candidate rules:
1. <rule text> (from <project-id>, was <R-ID> there)
   Severity: <severity>
   Used in N of N past projects. [Recommended / Consider if …]

Candidate lessons-learned:
- <project-id>: "<lesson>"
```

Accepted rules enter the new project with fresh IDs and
`lesson-from: <source-project-id>` in provenance.

## Full spec

To be written during Phase 3 of the implementation plan.
See docs/implementation-guide.md §20.
