#!/usr/bin/env -S bash

printf '```bash\n$ %s\n' "${*}"
"$@"
s=$?
printf '```\n'
exit $s
