#!/usr/bin/env bash -e

printf '```bash
$ %s\n' "${*}"
${*}
s=$?
printf '```\n'
exit $s
