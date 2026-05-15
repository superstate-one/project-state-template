# Updating from the template

Every project state repo starts as a copy of the template (without
`.git`). The template evolves — new skills, generator improvements,
CLAUDE.md refinements, schema bumps — and you'll want to pull those
into existing project repos without losing the project-specific state
you've built up.

`scripts/update-from-template.sh` is the supported mechanism. It pulls
template-owned infrastructure from the template repo and leaves
project-owned state alone.

## What's template-owned vs. project-owned

**Template-owned** (the updater overwrites these):

- `.claude/skills/`
- `.claude/generators/`
- `.claude/schema-version.yaml`
- `scripts/`
- `CLAUDE.md`
- `docs/`

**Project-owned** (the updater never touches these):

- `roles/`, `entities/`, `features/`, `flows/`, `rules/`,
  `decisions/`, `questions/`, `feedback/`, `risks/`, `stakeholders/`,
  `integrations/`
- `generated/`
- `project.yaml`, `state-index.yaml`
- `README.md` (project-customised during first-run setup)

The full whitelist of template-owned paths is at the top of
`scripts/update-from-template.sh`.

## Usage

From the repo root:

```bash
# Dry run — shows the diff against template/main.
scripts/update-from-template.sh

# Apply — stages the template versions of whitelisted paths.
scripts/update-from-template.sh --apply

# Review and commit.
git diff --cached
git commit -m "template: pull infrastructure updates"
```

The first run will add a `template` git remote pointing at
`git@github.com:superstate-one/project-state-template.git`. Override
with `TEMPLATE_URL=…` or `TEMPLATE_BRANCH=…` if needed.

## How self-update works

The script's first action is to compare its own contents against the
template's copy. If they differ, it replaces itself and re-execs. This
means improvements to the updater ship with each template update — you
never have to manually update the updater.

## Pre-flight checks

The updater refuses to run if:

- You have **uncommitted changes** in any template-owned path. Commit
  or stash first.
- The template's **schema major version** differs from local. This
  signals a breaking schema change that needs a migration step, not a
  blind overwrite.

## Schema migrations

When the schema major version bumps (e.g. v0 → v1), template content
may rely on fields that don't exist in project-owned entries yet, or
fields that have moved. The updater stops; you handle the migration
first.

Migration playbooks live in `docs/migrations/<from>-to-<to>.md` in the
template (added when each breaking bump ships). The typical flow:

1. Read the migration playbook for the version pair.
2. Run the state-updater with the playbook as input — it proposes the
   schema-shape changes to project-owned entries through normal
   extraction-report / structured-diff review.
3. Approve and commit the migration.
4. Re-run `scripts/update-from-template.sh --apply` to pull the rest
   of the template infrastructure.

## Conflicts and edge cases

- **You've edited a template-owned file locally.** The updater treats
  template content as authoritative on these paths. Your edits are
  overwritten by `--apply`. If a local change is worth keeping, send
  it back to the template via PR instead.
- **The template removed a file.** `--apply` deletes it locally too,
  via `git checkout`. The deletion shows in `git diff --cached`.
- **You're on a feature branch.** The updater works on any branch.
  Stage and commit the update on the branch you want.

## When *not* to use the updater

- For a brand-new project clone: the template content is already at
  HEAD; no update needed until the template moves.
- For project state changes (new feature, new rule, etc.): use the
  state-updater skill, not this script.
- For one-off cherry-picks from another project: do it by hand, not
  through this mechanism.
