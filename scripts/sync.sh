#!/usr/bin/env bash
# Sync vendored skills from upstream repos per scripts/catalog.json.
# Idempotent: rm -rf each target before copying. Does not auto-commit.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CATALOG="$SCRIPT_DIR/catalog.json"
SKILLS_DIR="$SCRIPT_DIR/../skills"

# Resolve repo basename for clone dir naming.
repo_basename() {
  local url="$1"
  local name="${url##*/}"
  name="${name%.git}"
  printf '%s' "$name"
}

# Validate catalog.
if [[ ! -f "$CATALOG" ]]; then
  echo "ERROR: catalog.json not found at $CATALOG" >&2
  exit 1
fi
if ! python3 -m json.tool "$CATALOG" >/dev/null 2>&1; then
  echo "ERROR: catalog.json is not valid JSON" >&2
  exit 1
fi

TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

# Track cloned repos: newline-delimited "repo<TAB>path" pairs (bash 3.2 compatible).
CLONED_REPOS=""
CLONED_PATHS=""

synced=0
skipped=0
failed=0

# Read catalog entries via python (jq not guaranteed). bash 3.2 has no mapfile.
ENTRIES="$(python3 -c '
import json, sys
with open(sys.argv[1]) as f:
    for e in json.load(f):
        print("\t".join([e["name"], e["category"], e["repo"], e["subdir"]]))
' "$CATALOG")"

while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  IFS=$'\t' read -r name category repo subdir <<<"$line"
  base="$(repo_basename "$repo")"

  # Clone once per repo: look up by repo URL in CLONED_REPOS.
  src=""
  if [[ -n "$CLONED_REPOS" ]]; then
    idx=0
    IFS=$'\n'
    for r in $CLONED_REPOS; do
      if [[ "$r" == "$repo" ]]; then
        src="$(echo "$CLONED_PATHS" | sed -n "$((idx + 1))p")"
        break
      fi
      idx=$((idx + 1))
    done
    unset IFS
  fi

  if [[ -z "$src" ]]; then
    echo "Cloning $repo ..."
    clone_ok=0
    for attempt in 1 2 3; do
      if git clone --depth 1 "$repo" "$TMPDIR/$base" 2>/dev/null; then
        clone_ok=1
        break
      fi
      rm -rf "${TMPDIR:?}/$base"
      [[ $attempt -lt 3 ]] && sleep 2
    done
    if [[ $clone_ok -eq 1 ]]; then
      src="$TMPDIR/$base"
      if [[ -n "$CLONED_REPOS" ]]; then
        CLONED_REPOS="$CLONED_REPOS"$'\n'"$repo"
        CLONED_PATHS="$CLONED_PATHS"$'\n'"$src"
      else
        CLONED_REPOS="$repo"
        CLONED_PATHS="$src"
      fi
    else
      echo "  WARN: clone failed for $repo (after 3 attempts), skipping $name" >&2
      failed=$((failed + 1))
      continue
    fi
  fi

  if [[ "$subdir" != "." ]]; then
    src="$src/$subdir"
  fi

  if [[ ! -f "$src/SKILL.md" ]]; then
    echo "  WARN: no SKILL.md in $src, skipping $name" >&2
    skipped=$((skipped + 1))
    continue
  fi

  target="$SKILLS_DIR/$category/$name"
  rm -rf "${target:?}"
  mkdir -p "$target"
  # Copy upstream contents, excluding the .git dir (don't vendor git history).
  if command -v rsync >/dev/null 2>&1; then
    rsync -a --exclude='.git' "$src/" "$target/"
  else
    # Fallback: tar pipe excluding .git (portable, no rsync needed).
    ( cd "$src" && tar -cf - --exclude='./.git' . ) | ( cd "$target" && tar -xf - )
  fi

  # Remove upstream packaging artifacts: a nested skills/ subdir that ships its
  # own SKILL.md (e.g. twostraws repos contain <skill>/skills/<skill>/SKILL.md).
  # We keep only the top-level SKILL.md as the canonical vendored skill.
  if [[ -d "$target/skills" ]] && find "$target/skills" -name SKILL.md -print -quit | grep -q .; then
    rm -rf "${target:?}/skills"
  fi

  # Warn if frontmatter name missing.
  if ! head -10 "$target/SKILL.md" | grep -q '^name:'; then
    echo "  WARN: $name SKILL.md missing frontmatter name field" >&2
  fi

  echo "  synced: $category/$name"
  synced=$((synced + 1))
done <<<"$ENTRIES"

echo ""
echo "Sync complete: $synced synced, $skipped skipped, $failed failed."
