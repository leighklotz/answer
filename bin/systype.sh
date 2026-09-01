#!/usr/bin/env -S bash -e

SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE}")")"
source "${SCRIPT_DIR}/env.sh"
source "${SCRIPT_DIR}/logging.sh"
source "${SCRIPT_DIR}/functions.sh"

printf "%s" "$COMPUTER_ICON" >&2
printf '# Description of this system:\n'
printf '```bash\n'
printf '$ uname -a\n'
uname -a
printf '$ cat /etc/os-release\n'
egrep -v '^[A-Z_]+_URL="http' /etc/os-release 
printf '```\n'
