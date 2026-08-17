#!/usr/bin/env -S bash -e

SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE}")")"
source "${SCRIPT_DIR}/env.sh"
source "${SCRIPT_DIR}/logging.sh"
source "${SCRIPT_DIR}/functions.sh"
ENABLE_CORE_SH="${SCRIPT_DIR}/enable-core.sh"

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
      echo "Skipping $doc_md because $doc_md_new exists"
    else
        if [ -f "${SCRIPT_DIR}/${cmd}.sh" ]; then
            src="${SCRIPT_DIR}/${cmd}.sh"
        else
            src="${ENABLE_CORE_SH}"
        fi
        echo -ne "->${src}\t" >&2

        context=($MAKEDOC_PREREADING)
        [ -n "$src" ] && context+=("$src")

        if [ -f $doc_md ]; then
            prompt="Check and update the usage document \`doc/commands/${cmd}.md\` for the $cmd command implemented in $src. Output the new usage file, not delta instructions. Bias towards making small changes based on script code changes, and avoid editorial changes unless necessary. If the usage document does not largely correspond to the implementation, note that fact do not output the new file. "
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
