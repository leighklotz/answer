#!/usr/bin/env -S bash

printf '```bash
$ %s\n' "${*}"
${*}
s=$?
printf '```\n'
exit $s
