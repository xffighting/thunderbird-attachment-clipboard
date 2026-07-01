#!/usr/bin/env bash
# scripts/lint_js.sh — eslint over extension/src
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
cd "$ROOT"

if ! command -v npm >/dev/null 2>&1; then
  echo "npm missing; install Node 20+ and try again" >&2
  exit 1
fi

# Reuse the same .eslintrc.json that CI commits; fall back to a
# minimal inline config for callers without npm cache.
ESLINTRC="$ROOT/.eslintrc.json"
if [[ ! -f "$ESLINTRC" ]]; then
  cat > .eslintrc.json <<'JSON'
{
  "root": true,
  "env": { "browser": true, "webextensions": true, "es2022": true },
  "parserOptions": { "ecmaVersion": 2022, "sourceType": "module" },
  "globals": {
    "browser": "readonly",
    "chrome": "readonly",
    "messenger": "readonly"
  },
  "rules": {
    "no-unused-vars": ["warn", { "argsIgnorePattern": "^_" }],
    "no-undef": "error",
    "no-var": "error",
    "prefer-const": "warn",
    "eqeqeq": ["error", "always"],
    "semi": ["error", "always"],
    "indent": ["error", 2, { "SwitchCase": 1 }]
  }
}
JSON
fi

if [[ ! -d "$ROOT/node_modules/eslint" ]]; then
  npm install --no-save --silent eslint@8 >/dev/null
fi

npx --no-install eslint extension/src "$@"
