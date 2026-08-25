#!/usr/bin/env bash
set -euo pipefail

TEST_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
cd "${TEST_DIR}"
# shellcheck source=../bin/logging.sh
source "../bin/logging.sh"

failures=0
INFO=1
DEBUG="${DEBUG:-}"
VERBOSE="${VERBOSE:-}"
TRACE="${TRACE:-}"

# Load only strip_markdown_fence from scuttle.sh (avoid running the full script).
# Track brace depth so nested blocks do not truncate the function body.
eval "$(awk '
  /^function strip_markdown_fence/ { capturing=1 }
  capturing {
    print
    for (i = 1; i <= length($0); i++) {
      c = substr($0, i, 1)
      if (c == "{") depth++
      else if (c == "}") depth--
    }
    if (depth == 0) exit
  }
' ../bin/scuttle.sh)"
if ! declare -F strip_markdown_fence >/dev/null; then
  log_error "strip_markdown_fence not defined"
  exit 1
fi

run_test() {
  local description="$1"
  local input="$2"
  local expected="$3"
  local actual
  actual="$(printf '%s' "$input" | strip_markdown_fence)"
  echo "Testing: $description"
  if [[ "$actual" == "$expected" ]]; then
    log_info "PASS"
  else
    log_error "FAIL: expected vs actual differ"
    printf 'EXPECTED:\n%s\nACTUAL:\n%s\n' "$expected" "$actual" >&2
    failures=$((failures + 1))
  fi
  echo "---"
}

YAML_BODY='link: https://example.com
title: "Example"
description: |
  A short summary.
keywords:
  - example
  - test
'

run_test 'yaml fence with language tag' \
  "$(printf '```yaml\n%s```\n' "$YAML_BODY")" \
  "$(printf '%s' "$YAML_BODY")"

run_test 'bare fence without language tag' \
  "$(printf '```\n%s```\n' "$YAML_BODY")" \
  "$(printf '%s' "$YAML_BODY")"

run_test 'raw yaml without fence is unchanged' \
  "$(printf '%s' "$YAML_BODY")" \
  "$(printf '%s' "$YAML_BODY")"

run_test 'error yaml fenced' \
  "$(printf '```yaml\nlink: https://example.com\nerror: |\n  captcha\n```\n')" \
  "$(printf 'link: https://example.com\nerror: |\n  captcha\n')"

# Ensure result is valid enough for yaml parsers that reject leading backticks.
if printf '```yaml\nlink: https://example.com\ntitle: "T"\n```\n' | strip_markdown_fence | grep -q '^```'; then
  log_error "FAIL: stripped output still contains a fence"
  failures=$((failures + 1))
else
  log_info "PASS: no residual fence markers on first/last lines path"
fi

if (( failures > 0 )); then
  echo "$failures test(s) failed."
  exit 1
fi

echo "All scuttle fence tests passed."
