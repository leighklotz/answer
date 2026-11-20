#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE}")")"

source "${SCRIPT_DIR}/env.sh"
source "${SCRIPT_DIR}/logging.sh"
source ${SCRIPT_DIR}/commands/hx-bootstrap.sh

hx core

p=-1
read -r p < <(decide --json "Deploy Gate" select is_good noul "Is this configuration valid, complete, and safe to deploy without further changes?" | jq -e -r '((.is_good.noul // -1) * 100 | floor)')

if (( p < 0 )); then
  emit_icon_tooltip "$ERROR_ICON" "No data"
  printf "could not decide\n"
  exit 2
elif (( p >= 70 )); then
  emit_icon_tooltip "$GREEN_CHECK_ICON" "Good to go"
  printf "good to go (p=%s%%)\n" "${p}"
  exit 0
else
  emit_icon_tooltip "$EXIT_ICON" "Not ready"
  printf "not ready (p=%s%%)\n" "${p}"
  exit 1
fi
