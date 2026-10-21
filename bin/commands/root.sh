#!/usr/bin/env -S bash

SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE}")")"
source "${SCRIPT_DIR}/../env.sh"
source "${SCRIPT_DIR}/../functions.sh"

dot_hallux_dir="$(_find_dot_hallux_dir)"

case "${1:---relative}" in
    --relative)
        _relative_path "$PWD" "$dot_hallux_dir"
        ;;
    --absolute)
        realpath "$dot_hallux_dir"
        ;;
    *)
        printf 'usage: %s [--relative | --absolute]\n' "$0" >&2
        exit 1
        ;;
esac
