#!/usr/bin/env bash
# Fail if any manifest doesn't parse or Claude Code rejects the marketplace or a plugin.
set -euo pipefail
cd "$(dirname "$0")/.."

for f in .claude-plugin/marketplace.json sources.json upstream-lock.json plugins/*/.claude-plugin/plugin.json; do
  jq empty "$f" || { echo "Invalid JSON: $f" >&2; exit 1; }
done

if command -v claude >/dev/null; then
  claude plugin validate .
  for p in plugins/*/; do
    claude plugin validate "$p"
  done
else
  echo "claude CLI not found; skipped claude plugin validate" >&2
fi
