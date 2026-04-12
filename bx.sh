#!/usr/bin/env -S bash -e

printf '```bash
$ %s\n' "${*}"
${*}
s=$?
printf '```\n'
exit $s
