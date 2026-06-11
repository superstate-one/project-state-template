#!/usr/bin/env bash
# Update a project-state repository from the template.
#
# Usage:
#   scripts/update-from-template.sh             # dry-run: shows the diff
#   scripts/update-from-template.sh --apply     # stages template-owned paths
#
# The script self-updates as its first action: if the template's copy of
# this script differs from the local copy, the local copy is replaced and
# the new version is re-exec'd. This means improvements to the updater
# ship automatically with each template update.
#
# Only template-owned paths are touched (see PATHS below). Project-owned
# directories — roles/, entities/, features/, flows/, rules/, decisions/,
# questions/, feedback/, risks/, stakeholders/, integrations/, generated/,
# and the project.yaml / state-index.yaml files — are never modified by
# this script.
#
# Compatibility: assumes future versions of this script accept the same
# CLI surface ("--apply" or no args). Breaking changes to the CLI must be
# rolled out via a deprecation cycle.

set -euo pipefail

TEMPLATE_REMOTE="${TEMPLATE_REMOTE:-template}"
TEMPLATE_URL="${TEMPLATE_URL:-git@github.com:superstate-one/project-state-template.git}"
TEMPLATE_BRANCH="${TEMPLATE_BRANCH:-main}"
SCRIPT_PATH="scripts/update-from-template.sh"

# Whitelist of template-owned paths. Project-owned paths are NEVER listed
# here. When the template adds a new infrastructure path, add it here in
# the same template commit.
PATHS=(
  .claude/skills
  .claude/generators
  .claude/schema-version.yaml
  scripts
  CLAUDE.md
  docs
)

# ---------------------------------------------------------------------------

# Must run from repo root.
if [ ! -d .git ]; then
  echo "error: must be run from the root of a project-state repository" >&2
  exit 1
fi

# Ensure template remote exists and points at the right URL.
if ! git remote get-url "$TEMPLATE_REMOTE" >/dev/null 2>&1; then
  echo "Adding template remote: $TEMPLATE_URL"
  git remote add "$TEMPLATE_REMOTE" "$TEMPLATE_URL"
fi

echo "Fetching $TEMPLATE_REMOTE/$TEMPLATE_BRANCH…"
git fetch --quiet "$TEMPLATE_REMOTE" "$TEMPLATE_BRANCH"

# Self-update gate. Compare the local script blob to the template's.
# If they differ and we haven't already self-updated this run, replace
# the local script and re-exec.
if [ "${SELF_UPDATED:-0}" != "1" ]; then
  LOCAL_SHA=$(git hash-object "$SCRIPT_PATH")
  REMOTE_SHA=$(git rev-parse "$TEMPLATE_REMOTE/$TEMPLATE_BRANCH:$SCRIPT_PATH" 2>/dev/null || echo "")
  if [ -n "$REMOTE_SHA" ] && [ "$LOCAL_SHA" != "$REMOTE_SHA" ]; then
    echo "Updater script differs from template. Replacing and re-running…"
    git checkout "$TEMPLATE_REMOTE/$TEMPLATE_BRANCH" -- "$SCRIPT_PATH"
    chmod +x "$SCRIPT_PATH"
    SELF_UPDATED=1 exec "./$SCRIPT_PATH" "$@"
  fi
fi

# Refuse to run if there are uncommitted changes in any whitelisted path —
# we'd overwrite them silently.
DIRTY=$(git status --porcelain -- "${PATHS[@]}" || true)
if [ -n "$DIRTY" ]; then
  echo "error: uncommitted changes in template-owned paths:" >&2
  echo "$DIRTY" >&2
  echo "Commit or stash before running the updater." >&2
  exit 1
fi

# Schema-version compatibility gate. If the template bumped the major
# version of the schema, refuse to apply and point at migrations.
if git cat-file -e "$TEMPLATE_REMOTE/$TEMPLATE_BRANCH:.claude/schema-version.yaml" 2>/dev/null \
   && [ -f .claude/schema-version.yaml ]; then
  LOCAL_MAJOR=$(grep -E '^version:' .claude/schema-version.yaml | sed -E 's/.*v?([0-9]+).*/\1/' || echo "")
  REMOTE_MAJOR=$(git show "$TEMPLATE_REMOTE/$TEMPLATE_BRANCH:.claude/schema-version.yaml" \
    | grep -E '^version:' | sed -E 's/.*v?([0-9]+).*/\1/' || echo "")
  if [ -n "$LOCAL_MAJOR" ] && [ -n "$REMOTE_MAJOR" ] && [ "$LOCAL_MAJOR" != "$REMOTE_MAJOR" ]; then
    echo "error: schema major version differs (local v$LOCAL_MAJOR, template v$REMOTE_MAJOR)." >&2
    echo "A migration is required. See docs/updating-from-template.md." >&2
    exit 2
  fi
fi

# Compute the diff and the deletion set. `git checkout <remote> -- <path>` only
# overlays files; it never removes them. Files that exist locally under a
# whitelisted path but no longer exist on the template side were deleted (or
# renamed) there — their removal will be applied at --apply time by the deletion
# sync below. Paths absent on the template side are skipped here (no pathspec
# noise) and handled entirely by that sync.
echo
echo "Changes from $TEMPLATE_REMOTE/$TEMPLATE_BRANCH on template-owned paths:"
echo "---------------------------------------------------------------"
HAS_DIFF=0
for p in "${PATHS[@]}"; do
  if ! git cat-file -e "$TEMPLATE_REMOTE/$TEMPLATE_BRANCH:$p" 2>/dev/null; then
    continue   # absent on template side — deletion sync handles local copies
  fi
  if ! git diff --quiet "$TEMPLATE_REMOTE/$TEMPLATE_BRANCH" -- "$p" 2>/dev/null; then
    HAS_DIFF=1
    git --no-pager diff --stat "$TEMPLATE_REMOTE/$TEMPLATE_BRANCH" -- "$p"
  fi
done

# Deletion sync: local tracked files under whitelisted paths that are not
# present on the template side. Uses ONLY the PATHS array — nothing outside the
# whitelist is ever considered.
STALE=$(comm -23 \
  <(git ls-files -- "${PATHS[@]}" | sort -u) \
  <(for p in "${PATHS[@]}"; do \
      git ls-tree -r --name-only "$TEMPLATE_REMOTE/$TEMPLATE_BRANCH" -- "$p" 2>/dev/null; \
    done | sort -u))

if [ -n "$STALE" ]; then
  HAS_DIFF=1
  echo
  echo "Will delete (removed on template side):"
  printf '%s\n' "$STALE" | sed 's/^/  /'
fi

if [ "$HAS_DIFF" = "0" ]; then
  echo "(no changes — already up to date)"
  exit 0
fi

if [ "${1:-}" != "--apply" ]; then
  echo
  echo "Re-run with --apply to stage these changes. Full diff:"
  echo "  git diff $TEMPLATE_REMOTE/$TEMPLATE_BRANCH -- ${PATHS[*]}"
  exit 0
fi

# Apply: check out template versions per path (so a path that does not exist on
# the template side does not abort the whole apply), then stage deletions for
# files removed on the template side.
echo
echo "Staging template versions of whitelisted paths…"
for p in "${PATHS[@]}"; do
  if git cat-file -e "$TEMPLATE_REMOTE/$TEMPLATE_BRANCH:$p" 2>/dev/null; then
    git checkout "$TEMPLATE_REMOTE/$TEMPLATE_BRANCH" -- "$p"
  else
    echo "note: '$p' does not exist on the template side — local copy handled by deletion sync"
  fi
done

if [ -n "$STALE" ]; then
  echo "Staging deletions removed on the template side…"
  printf '%s\n' "$STALE" | while IFS= read -r f; do
    [ -n "$f" ] && git rm -q -- "$f"
  done
fi

echo
echo "Done. Review with 'git diff --cached', then commit:"
echo "  git commit -m 'template: pull infrastructure updates'"
