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
emit_icon_tooltip "$COMPUTER_ICON" "$(uname -sr)..."
egrep -v '^[A-Z_]+_URL="http' /etc/os-release 
printf '```\n'
