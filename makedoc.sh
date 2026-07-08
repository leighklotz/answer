#!/usr/bin/env -S bash -e

SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE}")")"
source "${SCRIPT_DIR}/env.sh"
source "${SCRIPT_DIR}/logging.sh"
source "${SCRIPT_DIR}/functions.sh"

shopt -s nullglob
mkdir -p doc

CMDS="answer ask bx help-commit help unfence lx hx"

if [ -n "$1" ]; then
    CMDS=$@
fi

echo "CMDS=$CMDS"

for cmd in $CMDS; do
    echo -n "cmd=$cmd "
    doc_md="doc/${cmd}.md"
    doc_md_new="doc/${cmd}.md.new"
    dest=""
    if [ -f "$doc_md_new" ]; then
      echo "Skipping $doc_md becasuse $doc_md_new exists"
    else
        if [ -f "${cmd}.sh" ]; then
            src="${cmd}.sh"
        else
            src="functions.sh"
        fi

        context=()
        [ -n "$src" ] && context+=("$src")

        if [ -f $doc_md ]; then
            prompt="Check and update the usage document \`doc/${cmd}.md\` for the $cmd command implemented in $src. Output the new usage file, not delta instructions."
            dest="${doc_md_new}"
        else
            prompt="Create the usage document \`doc/${cmd}.md\` for the $cmd command for $src"
            dest="${doc_md}"
        fi

        context+=(README.md tests/story-test.sh doc/*.md)
        lx "${context[@]}" | help "$prompt" | answer > "$dest"
        echo >&2
        if [ ! -s "$dest" ]; then
            log_and_exit 1 "$dest was empty"
        fi
    fi
done
