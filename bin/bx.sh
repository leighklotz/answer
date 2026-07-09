#!/usr/bin/env -S bash

printf '```bash\n$ %s\n' "${*}"
"$@"
s=$?
printf '```\n'
printf "🐚" >&2
exit $s
