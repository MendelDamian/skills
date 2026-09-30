#!/usr/bin/env bash
# Symlink every plugin's skills and agents into a tool's config dir, for use without the plugin marketplace.
# Usage: scripts/link.sh claude|opencode
# Existing non-symlink files are left alone.
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
for d in "$repo"/plugins/*/skills/*/; do link "${d%/}" "$base/skills"; done
for f in "$repo"/plugins/*/agents/*.md; do [ -e "$f" ] && link "$f" "$base/agents"; done
