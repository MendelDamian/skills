#!/usr/bin/env bash
# For each mirrored plugin in sources.json: copy upstream into plugins/<name> minus its `exclude` globs,
# drop `disable-model-invocation: true` from skills matching its `allowModelInvocation` globs,
# layer overlay/plugins/<name> on top, and on change bump its patch version and record the upstream SHA.
# Plugins not listed in sources.json are never touched.
set -euo pipefail
cd "$(dirname "$0")/.."

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

jq -c '.[]' sources.json | while read -r src; do
  name=$(jq -r .name <<<"$src")
  repo=$(jq -r .repo <<<"$src")
  path=$(jq -r .path <<<"$src")
  clone="$tmp/${repo//\//__}"

  [ -d "$clone" ] || git clone --depth 1 --quiet "https://github.com/$repo" "$clone"
  sha=$(git -C "$clone" rev-parse HEAD)

  jq -r '.exclude[]? | "/" + .' <<<"$src" > "$tmp/exclude"
  rsync -a --delete --delete-excluded --exclude .git --exclude-from="$tmp/exclude" "$clone/$path/" "plugins/$name/"

  allowed=$(jq -r '.allowModelInvocation[]?' <<<"$src")
  for skill in "plugins/$name"/skills/*/SKILL.md; do
    dir=$(basename "$(dirname "$skill")")
    while read -r pattern; do
      if [[ -n $pattern && $dir == $pattern ]]; then
        perl -i -pe '$fm++ if /^---\s*$/; $_ = "" if $fm == 1 && /^disable-model-invocation:\s*true\s*$/' "$skill"
        break
      fi
    done <<<"$allowed"
  done
  [ -d "overlay/plugins/$name" ] && rsync -a "overlay/plugins/$name/" "plugins/$name/"

  if [ -n "$(git status --porcelain -- "plugins/$name")" ]; then
    manifest="overlay/plugins/$name/.claude-plugin/plugin.json"
    IFS=. read -r major minor patch < <(jq -r .version "$manifest")
    version="$major.$minor.$((patch + 1))"
    jq --arg v "$version" '.version = $v' "$manifest" > "$manifest.tmp" && mv "$manifest.tmp" "$manifest"
    cp "$manifest" "plugins/$name/.claude-plugin/plugin.json"
    jq --arg n "$name" --arg s "$sha" '.[$n] = $s' upstream-lock.json > upstream-lock.json.tmp && mv upstream-lock.json.tmp upstream-lock.json
    echo "$name v$version ($repo@${sha:0:7})" | tee -a "${SYNC_LOG:-/dev/null}"
  fi
done
