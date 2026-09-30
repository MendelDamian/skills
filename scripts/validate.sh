#!/usr/bin/env bash
# Fail if manifests don't parse or Claude Code rejects the marketplace/plugin.
set -euo pipefail
cd "$(dirname "$0")/.."

for f in .claude-plugin/marketplace.json pstack/.claude-plugin/plugin.json; do
  jq empty "$f" || { echo "Invalid JSON: $f" >&2; exit 1; }
done

if command -v claude >/dev/null; then
  claude plugin validate .
  claude plugin validate ./pstack
else
  echo "claude CLI not found; skipped claude plugin validate" >&2
fi
