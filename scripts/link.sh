#!/usr/bin/env bash
# Symlink every plugin's skills and agents into a tool's config dir, for use without the plugin marketplace.
# Skills are discovered by SKILL.md, so nested layouts (skills/<category>/<skill>) work too.
# Usage: scripts/link.sh claude|opencode
# Existing non-symlink files are left alone; dangling symlinks are pruned.
set -euo pipefail
cd "$(dirname "$0")/.."
repo=$(pwd)

case "${1:-}" in
  claude)   base="$HOME/.claude" ;;
  opencode) base="$HOME/.config/opencode" ;;
  *) echo "Usage: $0 claude|opencode" >&2; exit 1 ;;
esac

link() {
  local target="$2/$(basename "$1")"
  if [ -e "$target" ] && [ ! -L "$target" ]; then
    echo "skip (exists): $target" >&2
    return
  fi
  ln -sfn "$1" "$target"
  echo "linked: $target"
}

mkdir -p "$base/skills" "$base/agents"

for d in "$base"/skills/* "$base"/agents/*; do
  if [ -L "$d" ] && [ ! -e "$d" ]; then
    rm -f "$d"
    echo "pruned: $d" >&2
  fi
done

while IFS= read -r skill_md; do
  link "$(dirname "$skill_md")" "$base/skills"
done < <(find "$repo/plugins" -type f -name SKILL.md | sort)

for f in "$repo"/plugins/*/agents/*.md; do [ -e "$f" ] && link "$f" "$base/agents"; done
