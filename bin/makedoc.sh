#!/usr/bin/env -S bash

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

printf "CMDS=%s\n" "$CMDS"
printf "MAKEDOC_PREREADING=%s\n" "$MAKEDOC_PREREADING"

printf "%-16s%-32s%-32s%-32s%s\n" "cmd" "bin" "new doc" "Δ"

for cmd in $CMDS; do
    printf "%-16s" "$cmd"
    doc_md="doc/commands/${cmd}.md"
    doc_md_new="doc/commands/${cmd}.md.new"
    dest=""
    if [ -f "${SCRIPT_DIR}/${cmd}.sh" ]; then
        src="${SCRIPT_DIR}/${cmd}.sh"
    elif [ -f "${SCRIPT_DIR}/commands/${cmd}.sh" ]; then
        src="${SCRIPT_DIR}/commands/${cmd}.sh"
    else
        log_and_exit 1 "cannot find ${SCRIPT_DIR}/${cmd}.sh for doc_md_new=$doc_md_new "
    fi
    
    printf -- "%-32s%-32s" "$(sed "s|${SCRIPT_DIR}/||" <<< "$src")" "$doc_md_new" >&2

    if [ -f "$doc_md_new" ]; then
        dest="$doc_md_new"
    else
        context=($MAKEDOC_PREREADING)
        [ -n "$src" ] && context+=("$src")

        if [ -f $doc_md ]; then
            prompt="Check and update the usage document \`doc/commands/${cmd}.md\` for the $cmd command implemented in $src. Output the new usage file, not delta instructions. Bias towards making small changes based on correspondence with given command script. AVOID EDITORIAL CHANGES. If the usage document does not largely correspond to the implementation, note that fact and do not output the new file. If the file should be unchanged, output the literal text \`NO CHANGES\`."
            dest="${doc_md_new}"
        else
            prompt="Create the usage document \`doc/commands/${cmd}.md\` for the $cmd command for $src"
            dest="${doc_md}"
        fi

        context+=(README.md tests/story-test.sh doc/commands/*.md bin/logging.sh)
        lx "${context[@]}" | ask "$prompt" | answer | _strip_markdown_fence > "$dest" || log_and_exit 1 "pipeline failed"
    fi
    first_line="$(head -n1 "$dest")"
    [[ ! -s "$dest" ]] && log_and_exit 1 "$dest was empty"

    if [[ "$first_line" == "NO CHANGES" && "$doc_md" != "$dest" ]]; then
        cp "$doc_md" "$dest"
        printf "=\n"
    elif [[ "$first_line" == "NO CHANGES" ]] || { [ -f "$doc_md" ] && cmp -s "$doc_md" "$dest"; }; then
        printf "=\n"
    elif [ -s "$doc_md" ] && [ -s "$dest" ] && command -v diffstat &> /dev/null; then
        diff "$doc_md" "$dest" | diffstat | awk -F'|' '$2{gsub(/^[ \t]+/, "", $2); print $2}'
    else
        printf "? $doc_md $dest ?"
    fi
done
