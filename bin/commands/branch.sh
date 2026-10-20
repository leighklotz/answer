#!/bin/bash
set -euo pipefail

source "$(dirname "$0")/hx-bootstrap.sh"
hx core
printf "%s/%s" "$(hx root)" "$(git branch --show-current)"
[ -t 1 ] && echo
