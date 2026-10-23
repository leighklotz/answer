#!/usr/bin/env bash
SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE}")")"
source "${SCRIPT_DIR}/env.sh"
source "${SCRIPT_DIR}/logging.sh"

set -euo pipefail

emit_icon_tooltip "${CAT_ICON}" "bx -p cat -n"
xargs -n 1 bx -p cat -n
