#!/usr/bin/env bash
# Mirror upstream pstack/ into ./pstack, then layer ./overlay on top.
set -euo pipefail
cd "$(dirname "$0")/.."

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
git clone --depth 1 --quiet https://github.com/cursor/plugins "$tmp/up"

rsync -a --delete --exclude .git "$tmp/up/pstack/" ./pstack/
rsync -a ./overlay/ ./

# On any change to the mirrored content: bump the patch version and record the SHA.
# Unrelated upstream commits leave both untouched, so no empty syncs.
if [ -n "$(git status --porcelain -- pstack)" ]; then
  manifest=overlay/pstack/.claude-plugin/plugin.json
  IFS=. read -r major minor patch < <(jq -r .version "$manifest")
  version="$major.$minor.$((patch + 1))"
  jq --arg v "$version" '.version = $v' "$manifest" > "$manifest.tmp" && mv "$manifest.tmp" "$manifest"
  cp "$manifest" pstack/.claude-plugin/plugin.json
  git -C "$tmp/up" rev-parse HEAD > UPSTREAM_COMMIT
  echo "pstack changed; version $version"
fi
