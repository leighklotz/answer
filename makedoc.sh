#!/usr/bin/env -S bash -e

SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE}")")"
source "${SCRIPT_DIR}/env.sh"
source "${SCRIPT_DIR}/logging.sh"
source "${SCRIPT_DIR}/functions.sh"

shopt -s nullglob
mkdir -p doc

for cmd in answer ask bx help-commit help unfence; do
    echo -n "cmd=$cmd "
    if [ -f doc/"${cmd}.md" ]; then
        echo "- exists"
    else
        if [ -f "${cmd}.sh" ]; then
            SRC="${cmd}.sh"
        else
            SRC="functions.sh"
        fi

        DEST="doc/${cmd}.md"
        CTX_ARGS=()
        [ -n "$SRC" ] && CTX_ARGS+=("$SRC")
        CTX_ARGS+=(README.md tests/story-test.sh doc/*.md)

        echo "- documenting for $DEST"
        lx "${CTX_ARGS[@]}" | help "document the $cmd command for $DEST" | answer > "$DEST"
    fi
done
