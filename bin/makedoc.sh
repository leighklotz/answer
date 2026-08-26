#!/usr/bin/env -S bash -e

SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE}")")"
source "${SCRIPT_DIR}/env.sh"
source "${SCRIPT_DIR}/logging.sh"
source "${SCRIPT_DIR}/functions.sh"

cd "${SCRIPT_DIR}/.."

shopt -s nullglob
mkdir -p doc

CMDS="answer ask bx dreck help-commit help hx lx makedoc systype tools unfence"
: "${MAKEDOC_PREREADING:=}"

if [ -n "$1" ]; then
    CMDS=$@
fi

echo "CMDS=$CMDS"
echo "MAKEDOC_PREREADING=$MAKEDOC_PREREADING"

for cmd in $CMDS; do
    echo -n "cmd=$cmd"
    doc_md="doc/commands/${cmd}.md"
    doc_md_new="doc/commands/${cmd}.md.new"
    dest=""
    if [ -f "$doc_md_new" ]; then
      echo -e "\n* Skipping $doc_md because $doc_md_new exists; consider this:"
      echo -e "dreck $doc_md $doc_md_new"
    else
        if [ -f "${SCRIPT_DIR}/${cmd}.sh" ]; then
            src="${SCRIPT_DIR}/${cmd}.sh"
        elif [ -f "${SCRIPT_DIR}/commands/${cmd}.sh" ]; then
            src="${SCRIPT_DIR}/commands/${cmd}.sh"
        else
            log_and_exit 1 "cannot find ${SCRIPT_DIR}/${cmd}.sh for doc_md_new=$doc_md_new "
        fi
        echo -ne "->${src}\t" >&2

        context=($MAKEDOC_PREREADING)
        [ -n "$src" ] && context+=("$src")

        if [ -f $doc_md ]; then
            prompt="Check and update the usage document \`doc/commands/${cmd}.md\` for the $cmd command implemented in $src. Output the new usage file, not delta instructions. Bias towards making small changes based on correspondence with given command script. AVOID EDITORIAL CHANGES. If the usage document does not largely correspond to the implementation, note that fact do not output the new file."
            dest="${doc_md_new}"
        else
            prompt="Create the usage document \`doc/commands/${cmd}.md\` for the $cmd command for $src"
            dest="${doc_md}"
        fi

        context+=(README.md tests/story-test.sh doc/commands/*.md)
        lx "${context[@]}" | ask "$prompt" | answer > "$dest"
        echo >&2
        if [ ! -s "$dest" ]; then
            log_and_exit 1 "$dest was empty"
        fi
    fi
done
