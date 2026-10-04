#!/usr/bin/env -S bash

SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE}")")"

source "$SCRIPT_DIR/logging.sh"

plain=""
if [[ "$1" == "-p" || "$1" == "--plain" ]]; then
  plain=1
  shift
fi

[[ -z "$plain" ]] && printf '```bash\n'
printf '$ %s\n' "${*}"
"$@"
s=$?
[[ -z "$plain" ]] && printf '```\n'
printf '%s' "${SHELL_ICON}" >&2
exit $s
