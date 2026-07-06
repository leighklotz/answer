#!/usr/bin/env -S bash -ex

SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE}")")"
source "${SCRIPT_DIR}/env.sh"
source "${SCRIPT_DIR}/logging.sh"
source "${SCRIPT_DIR}/functions.sh"

shopt -s nullglob
mkdir -p doc

for cmd in answer ask bx help-commit help unfence; do
    echo -n "cmd=$cmd "
    doc_md="doc/${cmd}.md"
    doc_md_new="doc/${cmd}.md.new"
    dest=""
    if [ -f "${cmd}.sh" ]; then
        src="${cmd}.sh"
    else
        src="functions.sh"
    fi

    context=()
    [ -n "$src" ] && context+=("$src")

    if [ -f $doc_md ]; then
        prompt="Check and update the usage document for the $cmd command in $src"
        dest="${doc_md_new}"
    else
        prompt="Create the usage document for the $cmd command for $src"
        dest="${doc_md}"
    fi

    context+=(README.md tests/story-test.sh doc/*.md)
    lx "${context[@]}" | help "$prompt" | answer > "$dest"
    if [ ! -s "$dest" ]; then
        log_and_exit 1 "$dest was empty"
    fi
done
