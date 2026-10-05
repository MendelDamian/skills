#!/usr/bin/env bash
# For each mirrored plugin in sources.json: fetch the needed upstream files into plugins/<name>,
# drop `disable-model-invocation: true` from skills matching its `allowModelInvocation` globs,
# layer overlay/plugins/<name> on top, and on change bump its patch version and record the upstream SHA.
# Plugins not listed in sources.json are never touched.
#
# A source is one of:
#   { name, repo, path, dest?, exclude?, allowModelInvocation? }   copy <repo>/<path> into plugins/<name>/<dest>
#   { name, repo, paths: [{from, to}], allowModelInvocation? }     copy each <repo>/<from> into plugins/<name>/<to>
# `dest`/`to` default to the plugin root. `exclude` globs are relative to `path`. Repos are cloned
# shallow and sparsely (only the requested paths), so spreading a plugin across a large monorepo stays cheap.
set -euo pipefail
cd "$(dirname "$0")/.."

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

jq -c '.[]' sources.json | while read -r src; do
  name=$(jq -r .name <<<"$src")
  repo=$(jq -r .repo <<<"$src")
  clone="$tmp/${repo//\//__}"

  # Every path this source needs checked out (a single `path`, or each `paths[].from`).
  jq -r 'if .paths then .paths[].from else .path end' <<<"$src" > "$tmp/paths"
  needs_full=$(jq -r '(.paths // [{from: .path}]) | any(.from == ".")' <<<"$src")

  if [ ! -d "$clone" ]; then
    if [ "$needs_full" = "true" ]; then
      git clone --depth 1 --quiet "https://github.com/$repo" "$clone"
    else
      git clone --depth 1 --filter=blob:none --sparse --quiet "https://github.com/$repo" "$clone"
      git -C "$clone" sparse-checkout set --no-cone $(cat "$tmp/paths")
    fi
  fi
  sha=$(git -C "$clone" rev-parse HEAD)

  if jq -e '.paths' <<<"$src" >/dev/null; then
    rm -rf "plugins/$name"
    jq -c '.paths[]' <<<"$src" | while read -r p; do
      from=$(jq -r .from <<<"$p")
      to=$(jq -r '.to // "."' <<<"$p")
      mkdir -p "plugins/$name/$to"
      rsync -a --delete --exclude .git "$clone/$from/" "plugins/$name/$to/"
    done
  else
    path=$(jq -r .path <<<"$src")
    dest=$(jq -r '.dest // "."' <<<"$src")
    jq -r '.exclude[]? | "/" + .' <<<"$src" > "$tmp/exclude"
    mkdir -p "plugins/$name/$dest"
    rsync -a --delete --delete-excluded --exclude .git --exclude-from="$tmp/exclude" "$clone/$path/" "plugins/$name/$dest/"
  fi

  allowed=$(jq -r '.allowModelInvocation[]?' <<<"$src")
  for skill in "plugins/$name"/skills/*/SKILL.md; do
    [ -e "$skill" ] || continue
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
