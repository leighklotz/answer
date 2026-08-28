#!/usr/bin/env -S bash -e

SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE}")")"
source "${SCRIPT_DIR}/../env.sh"
source "${SCRIPT_DIR}/../logging.sh"

source "${SCRIPT_DIR}/hx-bootstrap.sh"
hx core

function _provenance_add() {
    local subcmd="$1"
    case "$subcmd" in 
        what|why|response|describe|-)
            last_cmd=$(fc -nl -2 | sed 's/^[[:space:]]*//')
            prompt_str="${PS1@P}"

            declare -A emoji=([what]=$CONVO_ICON [why]=$BRAIN_ICON [response]=$RESPONSE_ICON [describe]=$SCROLL_ICON [-]=$STDIN_ICON)
            declare -A ctype=([what]="$PIPELINE_TEXT_CONVO_HEADER" [why]="$PIPELINE_REASONING_CONVO_HEADER" [response]="$PIPELINE_MAGIC_HEADER" [describe]="$PIPELINE_TEXT_PLAIN_HEADER" [-]="$PIPELINE_TEXT_PLAIN_HEADER")

            local subcmd_emoji
            local content_type_header
            subcmd_emoji="${emoji[$subcmd]}"
            content_type_header="${ctype[$subcmd]}"                    

            printf "%shx provenance %s %s | git notes --ref=provenance/hallux append %s\n" "$SAVE_ICON" "$subcmd" "$subcmd_emoji" "$PIN_ICON" >&2

            local hx_out
            if [ "$subcmd" == "-" ]; then
                if [ -t 0 ]; then
                    echo "Provide hx provenance add input:" >&2
                fi
                hx_out="$(cat)"
            else
                hx_out=$(hx $subcmd || echo "[hx $subcmd failed or missing]")
            fi

            printf "%s%s\n%s\n%s\n\n" \
                   "$prompt_str" \
                   "$last_cmd" \
                   "${content_type_header}" \
                   "$hx_out" \
                | git notes --ref=provenance/hallux append -F -
            exit 0
            ;;
        "")
            echo "usage: hx provenance add [ what | why| response | describe | -]" >&2
            ;;

        *) echo "hx provenance add: unknown subcmd '$1'" >&2
           exit 1
           ;;
    esac
}

function _provenance_list() {
    git notes --ref=provenance/hallux list | while read -r note_hash commit_hash; do
        local log_line note_first_line preview
        log_line=$(git log -1 --oneline "$commit_hash")
        note_first_line=$(git notes --ref=provenance/hallux show "$commit_hash" 2>/dev/null | head -n 1)

        if (( ${#note_first_line} <= 43 )); then
            preview="$note_first_line"
        else
            preview="${note_first_line:0:20}...${note_first_line: -20}"
        fi

        local color_cyan='\x1b[36m'
        local nc='\x1b[0m'
        printf "%s %s${color_cyan}%s${nc}\n" "$log_line" "$PIN_ICON" "$preview"
    done
}
  
case "$1" in
    add)
        shift
        _provenance_add "$1"
    ;;
    show)
        shift
        # Instantly prints out your clean chronological append log for HEAD or a specific hash
        git notes --ref=provenance/hallux show "$1"
        exit 0
        ;;

    refs)
        # Scans the repo and lists hashes that have your tool's data attached
        git notes --ref=provenance/hallux list
        exit 0
        ;;

    list)
        # Decorated list that slices the first and last 20 characters of the first note line
        _provenance_list
        exit 0
        ;;

    *)
        echo "usage: hx provenance [ show | refs | list | add [ what | why | - ] ]" >&2
        exit 1
        ;;
esac
