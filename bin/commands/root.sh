#!/usr/bin/env -S bash

SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE}")")"
source "${SCRIPT_DIR}/../env.sh"
source "${SCRIPT_DIR}/../functions.sh"

if [ "${1:---relative}" == "--relative" ]; then
    printf "%s\n" "$(realpath --relative-to=. "$(_find_hallux_dir)")"
elif [ "${1:-}" == "--absolute" ]; then
    printf "%s\n" "$(realpath "$(_find_hallux_dir)")"
else
    printf "usage: %s [--relative | --absolute ] # default is --relative\n" "$0" >&2
    printf "       flag %s is unknown\n" "${1:--}" >&2
    exit 1
fi


