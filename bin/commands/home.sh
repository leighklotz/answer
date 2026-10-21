#!/usr/bin/env -S bash

SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE}")")"
HX_HOME="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../" && pwd -P)"
source "${SCRIPT_DIR}/../env.sh"
source "${SCRIPT_DIR}/../functions.sh"

case "${1:---relative}" in
    --relative)
        _relative_path "$PWD" "$HX_HOME"
        ;;
    --absolute)
        realpath "$HX_HOME"
        ;;
    *)
        printf 'usage: %s [--relative | --absolute]\n' "$0" >&2
        exit 1
        ;;
esac
