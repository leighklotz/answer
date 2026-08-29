#!/usr/bin/env -S bash

SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE}")")"
source "${SCRIPT_DIR}/../env.sh"
source "${SCRIPT_DIR}/../logging.sh"
source "${SCRIPT_DIR}/../functions.sh"

url="$VIA_API_CHAT_BASE"
h="${url#*://}"; h="${h%%/*}"; h="${h%%:*}"
printf "%s\n" "$h"
