#!/usr/bin/env bash
# scripts/lint_md.sh — markdownlint over docs/ and root *.md
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
cd "$ROOT"

if ! command -v markdownlint >/dev/null 2>&1; then
  if command -v npm >/dev/null 2>&1; then
    npm install -g markdownlint-cli@0.42 >/dev/null
  else
    echo "markdownlint + npm missing" >&2
    exit 1
  fi
fi

cat > .markdownlint.json <<'JSON' || true
{
  "default": true,
  "MD013": { "line_length": 100, "code_blocks": false, "tables": false },
  "MD033": false,
  "MD041": false,
  "MD024": { "siblings_only": true }
}
JSON

markdownlint '**/*.md' --ignore node_modules "$@"
