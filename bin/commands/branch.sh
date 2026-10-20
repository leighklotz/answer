#!/bin/bash
set -euo pipefail

source "$(dirname "$0")/hx-bootstrap.sh"
hx core

branch="$(git branch --show-current 2>/dev/null)"

if [[ -n "$branch" ]]; then
  printf "%s/%s" "$(hx root)" "$branch"
  [ -t 1 ] && echo
fi
