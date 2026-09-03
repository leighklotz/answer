#!/usr/bin/env -S bash

SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE}")")"
source "${SCRIPT_DIR}/../env.sh"
source "${SCRIPT_DIR}/../functions.sh"

printf "%s\n" "$(realpath --relative-to=. "$(_find_hallux_dir)")"


