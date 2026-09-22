#!/usr/bin/env -S bash

SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE}")")"
source "${SCRIPT_DIR}/../env.sh"
source "${SCRIPT_DIR}/../functions.sh"

relative_path() {
    local base target common up="" down

    base="$(realpath "$1")"
    target="$(realpath "$2")"
    common="$base"

    if [[ "$base" == "$target" ]]; then
        printf '.\n'
        return 0
    fi

    while [[ "$target" != "$common" && "$target" != "$common/"* ]]; do
        common="$(dirname "$common")"
        up+="../"
    done

    down="${target#"$common"}"
    down="${down#/}"

    printf '%s%s\n' "$up" "$down"
}

hallux_dir="$(_find_hallux_dir)"

case "${1:---relative}" in
    --relative)
        relative_path "$PWD" "$hallux_dir"
        ;;
    --absolute)
        realpath "$hallux_dir"
        ;;
    *)
        printf 'usage: %s [--relative | --absolute]\n' "$0" >&2
        exit 1
        ;;
esac
