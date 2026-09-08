#!/usr/bin/env -S bash -e

SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
source "${SCRIPT_DIR}/logging.sh"

set -o pipefail

usage() {
    echo "usage: $(basename "$0") [REV] FILE" >&2
    echo "       default REV is HEAD" >&2
}

case $# in
    1)
        REV=HEAD
        FILE=$1
        ;;
    2)
        REV=$1
        FILE=$2
        ;;
    *)
        usage
        exit 1
        ;;
esac

git rev-parse --is-inside-work-tree >/dev/null 2>&1 ||
    log_and_exit 1 "not in a git repository"

[[ -f "$FILE" ]] ||
    log_and_exit 1 "$FILE: not a regular file"

printf "%s" "$INBOX_ICON" >&2
bx git show "$REV:./$FILE"

printf "%s" "$INBOX_ICON" >&2
bx cat -- "$FILE"
