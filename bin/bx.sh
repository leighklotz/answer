#!/usr/bin/env bash

SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"

source "${SCRIPT_DIR}/env.sh"
source "${SCRIPT_DIR}/logging.sh"

plain=""
if [[ "$1" == "-p" || "$1" == "--plain" ]]; then
  plain=1
  shift
fi

if [[ $# -eq 0 ]]; then
  log_and_exit 1 "Error: No command provided."
fi

[[ -z "$plain" ]] && printf '```bash\n'
printf '$ %s\n' "$*"

exec 3>&1
{
  "$@" 2>&1 1>&3 3>&-
} | awk -v icon="${WARNING_ICON:-⚠️}" '{print icon " " $0}
s=${PIPESTATUS[0]}
exec 3>&-

[[ -z "$plain" ]] && printf '```\n'
[[ -n "${SHELL_ICON}" ]] && printf '%s' "${SHELL_ICON}" >&2

exit "$s"
