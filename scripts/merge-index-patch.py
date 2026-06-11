#!/usr/bin/env python3
"""
merge-index-patch.py — deterministic state-index.yaml patch merger (no LLM).

The state-updater never rewrites the whole index (a 3,000+ line file an LLM can
silently mangle). Instead it emits a *patch*: the full YAML blocks of the
entries it touched — keyed by `id` — plus blocks for new entries, in the same
two-space indentation they carry under `entries:`. This script swaps those
blocks into the index by `id`, appends new ones in order, refreshes the
`generated-at:` header, and writes the result back.

It is pure text-block manipulation — no YAML round-trip — so entries the patch
did not touch are preserved byte-for-byte, and the updater physically cannot
corrupt entries it did not emit.

Usage:
    python3 scripts/merge-index-patch.py <index-file> <patch-file> [--dry-run]

Patch file: one or more entry blocks, each beginning at column 2 with
"  - id: <ID>", exactly as they appear under `entries:` in the index. A header
(schema-version / generated-at / project-id / entries:) in the patch file, if
present, is ignored — only entry blocks are read.

Exit status: 0 on success, 2 on a malformed argument or file.
"""
import os
import re
import sys
import datetime

ENTRY_START = re.compile(r'^  - id:[ \t]*("?)([^"\n#]+?)\1[ \t]*(?:#.*)?$', re.M)


def _split_decoration(block):
    """Split a block into (content, trailing_decoration).

    Trailing decoration is the maximal suffix of lines that are blank or
    comment-only (first non-blank char is '#') — typically a section divider
    that textually trails this entry's block but visually belongs before the
    next entry. The patch never emits it, so on replace we must carry it over.
    """
    lines = block.splitlines(keepends=True)
    k = len(lines)
    while k > 0:
        stripped = lines[k - 1].strip()
        if stripped == "" or stripped.startswith("#"):
            k -= 1
        else:
            break
    return "".join(lines[:k]), "".join(lines[k:])


def split_entries(region: str):
    """Return (prefix, [(id, block), ...]) for text under `entries:`.

    `prefix` is whatever precedes the first entry (usually blank lines).
    Each block runs from its `  - id:` line up to the next one (or end),
    trailing newlines included, so reassembly is loss-free.
    """
    starts = [m.start() for m in ENTRY_START.finditer(region)]
    ids = [m.group(2).strip() for m in ENTRY_START.finditer(region)]
    if not starts:
        return region, []
    prefix = region[:starts[0]]
    blocks = []
    for i, start in enumerate(starts):
        end = starts[i + 1] if i + 1 < len(starts) else len(region)
        blocks.append((ids[i], region[start:end]))
    return prefix, blocks


def main(argv):
    args = [a for a in argv[1:] if not a.startswith("--")]
    dry = "--dry-run" in argv[1:]
    if len(args) != 2:
        sys.stderr.write(__doc__)
        return 2
    index_path, patch_path = args

    patch = open(patch_path, encoding="utf-8").read()
    try:
        base = open(index_path, encoding="utf-8").read()
    except FileNotFoundError:
        base = ""

    HEADER_RE = re.compile(r'^entries:[ \t]*(\[\][ \t]*)?$', re.M)

    if base.strip() == "":
        # Missing or empty index: bootstrap the header from the patch itself.
        # A rebuild patch includes the full index header (see the state-updater
        # skill); we use it as the new base and treat every block as an addition.
        pm = HEADER_RE.search(patch)
        if not pm:
            sys.stderr.write(
                "error: index file missing and patch carries no header; "
                "recreate the index header first (schema-version, generated-at, "
                "project-id, entries: [])\n")
            return 2
        header = patch[:pm.start()]
        prefix, base_blocks = "\n", []
    else:
        # Separate the header (through the `entries:` line) from the entries region.
        m = HEADER_RE.search(base)
        if not m:
            sys.stderr.write("error: no top-level `entries:` line in index\n")
            return 2
        header = base[:m.start()]
        region = base[m.end():]
        if region.startswith("\n"):
            region = region[1:]            # consumed by the normalized `entries:` line
        prefix, base_blocks = split_entries(region)
    _, patch_blocks = split_entries(patch)
    if not patch_blocks:
        sys.stderr.write("error: patch contains no `  - id:` entry blocks\n")
        return 2

    # Warn on duplicate ids within the patch (last block wins, but say so).
    seen = {}
    for bid, _ in patch_blocks:
        seen[bid] = seen.get(bid, 0) + 1
    dupes = [bid for bid, k in seen.items() if k > 1]
    if dupes:
        sys.stderr.write(
            "warning: duplicate id(s) in patch (last block wins): "
            + ", ".join(sorted(dupes)) + "\n"
        )

    order = [bid for bid, _ in base_blocks]
    by_id = {bid: blk for bid, blk in base_blocks}
    replaced, added = [], []
    for bid, blk in patch_blocks:
        if bid in by_id:
            replaced.append(bid)
            # Carry over any trailing section comment the old block held; the
            # patch block never includes it and it must not be silently dropped.
            _, deco = _split_decoration(by_id[bid])
            by_id[bid] = (blk.rstrip("\n") + "\n" + deco) if deco.strip() else blk
        else:
            order.append(bid)
            added.append(bid)
            by_id[bid] = blk

    if not prefix.strip("\n"):
        prefix = "\n"                  # keep one blank line after `entries:`

    # Normalise each block to a single trailing newline and join with one blank
    # line, so appended entries are spaced like the rest. Deterministic.
    norm = [by_id[bid].rstrip("\n") + "\n" for bid in order]
    merged_region = prefix + "\n".join(norm)
    now = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    header = re.sub(r'^generated-at:.*$', f'generated-at: {now}', header, count=1, flags=re.M)

    result = header + "entries:\n" + merged_region
    if not result.endswith("\n"):
        result += "\n"

    replaced_u = list(dict.fromkeys(replaced))   # de-dup for reporting (dupe patch ids)
    sys.stderr.write(
        f"merged: {len(replaced_u)} replaced ({', '.join(replaced_u) or '-'}), "
        f"{len(added)} added ({', '.join(added) or '-'}), "
        f"{len(order)} total; generated-at -> {now}\n"
    )
    if dry:
        sys.stdout.write(result)
    else:
        # Atomic write: write a temp file in the same directory, then replace.
        tmp = index_path + ".tmp"
        with open(tmp, "w", encoding="utf-8") as fh:
            fh.write(result)
        os.replace(tmp, index_path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
