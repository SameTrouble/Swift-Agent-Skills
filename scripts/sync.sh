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

declare -A CLONED

synced=0
skipped=0
failed=0

# Read catalog entries via python (jq not guaranteed).
mapfile -t ENTRIES < <(python3 -c '
import json, sys
with open(sys.argv[1]) as f:
    for e in json.load(f):
        print(f"{e[\"name\"]}\t{e[\"category\"]}\t{e[\"repo\"]}\t{e[\"subdir\"]}")
' "$CATALOG")

for line in "${ENTRIES[@]}"; do
  IFS=$'\t' read -r name category repo subdir <<<"$line"
  base="$(repo_basename "$repo")"

  # Clone once per repo.
  if [[ -z "${CLONED[$repo]:-}" ]]; then
    echo "Cloning $repo ..."
    if git clone --depth 1 "$repo" "$TMPDIR/$base" 2>/dev/null; then
      CLONED[$repo]="$TMPDIR/$base"
    else
      echo "  WARN: clone failed for $repo, skipping $name" >&2
      failed=$((failed + 1))
      continue
    fi
  fi

  src="${CLONED[$repo]}"
  if [[ "$subdir" != "." ]]; then
    src="$src/$subdir"
  fi

  if [[ ! -f "$src/SKILL.md" ]]; then
    echo "  WARN: no SKILL.md in $src, skipping $name" >&2
    skipped=$((skipped + 1))
    continue
  fi

  target="$SKILLS_DIR/$category/$name"
  mkdir -p "$target"
  rm -rf "${target:?}/"*
  cp -R "$src/." "$target/"

  # Warn if frontmatter name missing.
  if ! head -10 "$target/SKILL.md" | grep -q '^name:'; then
    echo "  WARN: $name SKILL.md missing frontmatter name field" >&2
  fi

  echo "  synced: $category/$name"
  synced=$((synced + 1))
done

echo ""
echo "Sync complete: $synced synced, $skipped skipped, $failed failed."
