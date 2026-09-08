#!/usr/bin/env -S bash

SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE}")")"
source "${SCRIPT_DIR}/env.sh"
source "${SCRIPT_DIR}/logging.sh"
source "${SCRIPT_DIR}/functions.sh"

cd "${SCRIPT_DIR}/.."

shopt -s nullglob
mkdir -p doc

CMDS="answer ask bx dreck gx help-commit help hx lx makedoc systype tools unfence"
: "${MAKEDOC_PREREADING:=}"

if [ -n "$1" ]; then
    CMDS=$@
fi

function make_update_prompt() {
    local cmd="$1"
    local src="$2"
    local prompt="
Check and update the usage document \`doc/commands/${cmd}.md\` for the \`$cmd\` based on the provided context and the following information: 
- The \`$cmd\` command is implemented at least partially by \`$src\` and also possibly by other bash functions or included/invoked files.
- For example the source for the \`hx\` command is in bash functions in \`bin/commands/hx-bootstrap.sh\` and in the script \`bin/commands/hx.sh\` and this implementation of \`hx\` subcommands is split across them.

Output: 
- IMPORTANT: AVOID EDITORIAL AND STYLE CHANGES.
- Bias towards making small changes based on correspondence with the given command script and its dependencies.
- If the usage document does not largely correspond to the implementation, note that fact and do not output the new file.
- If the file should be unchanged, output the literal text \`NO CHANGES\`.
- Output the new usage file, not delta instructions."
    printf "%s\n" "${prompt}"
}

function make_create_prompt() {
    local cmd="$1"
    local src="$2"
    prompt="Create the usage document \`doc/commands/${cmd}.md\` for the $cmd command for $src"
    printf "%s\n" "${prompt}"
}



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
        log_and_exit 1 "cannot find ${SCRIPT_DIR}/${cmd}.sh for doc_md_new=$doc_md_new"
    fi
    
    printf -- "%-32s%-32s" "$(sed "s|${SCRIPT_DIR}/||" <<< "$src")" "$doc_md_new" >&2

    if [ -f "$doc_md_new" ]; then
        dest="$doc_md_new"
    else
        context=($MAKEDOC_PREREADING)
        [ -n "$src" ] && context+=("$src")

        if [ -f $doc_md ]; then
	    prompt="$(make_update_prompt "$cmd" "$src")"
            dest="${doc_md_new}"
        else
	    prompt="$(make_create_prompt "$cmd" "$src")"
            dest="${doc_md}"
        fi

        context+=(README.md tests/story-test.sh doc/commands/*.md bin/logging.sh bin/commands/hx-bootstrap.sh bin/commands/hx.sh bin/functions.sh)
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
