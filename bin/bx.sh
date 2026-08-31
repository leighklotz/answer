#!/usr/bin/env -S bash

printf '```bash\n$ %s\n' "${*}"
"$@"
s=$?
printf '```\n'
printf '%s' "${SHELL_ICON}" >&2
exit $s
