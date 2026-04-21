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
