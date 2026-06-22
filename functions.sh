# source this file to define the functions

# Require bash 4+
if [ "${BASH_VERSINFO[0]}" -lt 4 ]; then
    echo "🦶ERROR: bash 4 or later is required (running ${BASH_VERSION})." >&2
    return 1 2>/dev/null
fi

# Check if ask.sh is available
if ! command -v ask.sh &> /dev/null; then
    echo "🦶$0: WARN: ask.sh is not on the PATH.  Please add the directory containing ask.sh to your PATH environment variable." >&2
fi

PIPELINE_MAGIC_HEADER="Content-Type: application/x-llm-history+json"

function ask ()
{
    local RAW_INPUT=""
    local ARGS=("$@")
    local is_attachment=false
    local has_stdin=false

    # 1. Determine if we are in "Attachment" mode via flags (-i / --input)
    for arg in "${ARGS[@]}"; do
        if [[ "$arg" == "-i" ]] || [[ "$arg" == "--input" ]]; then
            is_attachment=true
            break
        fi
    done

    # 2. Check if stdin has data without consuming it yet (using a temp file to allow re-reading)
    local tmpfile=$(mktemp)
    if [ ! -t 0 ]; then
        cat > "$tmpfile"
        has_stdin=true
    else
        has_stdin=false
    fi

    # Logic for building the input string based on detected mode
    if [ "$has_stdin" = true ]; then
        local first_line=$(head -n 1 "$tmpfile")
        if [ "$first_line" = "${PIPELINE_MAGIC_HEADER}" ] || [[ "$(echo "$first_line" | tr -d '[:space:]')" == "[" ]]; then
            # MODE: Conversation History (JSON)
            # If a prompt is provided in arguments, append it to the history. 
            if [ $# -gt 0 ]; then
                local clean_stdin=$(sed "1s/^${PIPELINE_MAGIC_HEADER}//" "$tmpfile")
                local new_message=$(jq -n --arg prompt "$*" '{"role":"user","content":$prompt}')
                RAW_INPUT=$(echo "$clean_stdin" | jq --argjson new_msg "$new_message" '$ + [$new_msg]')
            else
                # No extra prompt: treat the stdin JSON as the entire messages array.
                # This allows 'ask' to act as a pass-through for existing conversation states.
                RAW_INPUT=$(sed "1s/^${PIPELINE_MAGIC_HEADER}//" "$tmpfile")
            fi
        elif [ "$is_attachment" = true ] || [[ -z "$*" ]]; then
             # MODE: Text Attachment or raw context pipe
             echo "🦶ask: reading attachment/context from stdin" >&2
             RAW_INPUT=$(cat "$tmpfile")
        else
            # MODE: Plain text pipe (e.g., cmd | ask prompt) 
            echo "🦶ask: prepending piped data to prompt" >&2
            RAW_INPUT=$(cat "$tmpfile")
        fi
    fi

    rm -f "$tmpfile"

    # If no input was found and we aren't in a mode that expects it, exit silently.
    if [ "$has_stdin" = false ] && [ $# -eq 0 ]; then
        return 0
    fi

    # Execute the command (passing RAW_INPUT if constructed via jq logic or handling empty)
    local nascent=""
    if [[ "$RAW_INPUT" == *"{"* ]] || [[ "$RAW_INPUT" == "["* ]]; then
         # If we've built a JSON string, pass it to ask.sh as the input stream
         nascent=$(echo "$RAW_INPUT" | ask.sh "${ARGS[@]}")
    else
        # Regular text or command-line prompt mode
        nascent=$(ask.sh "${ARGS[@]}" <<< "$RAW_INPUT")
    fi

    local s=$?
    [ $s -ne 0 ] && { echo "🦶ask ERROR: ask.sh failed: $s" >&2; return 1; }

    # Refined logic for the specific requirement regarding pipes vs interactive mode
    if [ "$has_stdin" = true ]; then
        echo "🦶ask: chain detected via stdin, forcing answer." >&2
        answer <<< "${nascent}"
    elif [ -t 1 ]; then
        echo "🦶ask: interactive mode, calling answer" >&2
        answer <<< "${nascent}"
    else
        printf "%s\n" "${nascent}"
    fi
}

function answer ()
{
    local ANSWER_OUT
    ANSWER_OUT="$(answer.sh "$@")"
    local s=$?
    if [ $s -ne 0 ]; then
        echo "🦶answer ERROR: answer.sh failed with exit code $s" >&2
        return 1
    fi

    printf "%s\n" "${ANSWER_OUT}"
}

function bx ()
{
    local quiet
    while [[ $# -gt 0 ]]; do
        case "$1" in 
            -q) quiet=1; shift ;;
            -*) echo "🦶bx: unknown option $1" >&2; return 1 ;;
            *) break ;;
        esac
    done
 
    bx.sh "$@"
    local s=$?
    if [ $s -ne 0 ] && [ -z "${quiet}" ] ; then
        echo "🦶bx: ERROR: bx.sh failed with exit code $s" >&2
        return 1
    fi
}

function answer ()
{
    local ANSWER
    ANSWER="$(answer.sh "$@")"
    s=$?
    if [ $s -ne 0 ]; then
        echo "🦶answer ERROR: answer.sh failed with exit code $s" >&2
        return 1
    fi

    printf "%s\n" "${ANSWER}"
}

function bx ()
{
    local quiet
    while [[ $# -gt 0 ]]; do
        case "$1" in 
            -q) quiet=1; shift ;;
            -*) echo "🦶bx: unknown option $1" >&2; return 1 ;;
            *) break ;;
        esac
    done
 
    bx.sh "$@"
    s=$?
    if [ $s -ne 0 ] && [ -z "${quiet}" ] ; then
        echo "🦶bx: ERROR: bx.sh failed with exit code $s" >&2
        return 1
    fi
}

unfence ()
{
    unfence.sh "$@"
    s=$?
    if [ $s -ne 0 ]; then
        echo "🦶ERROR: unfence.sh failed with exit code $s" >&2
        return 1
    fi
}

function tools ()
{
    local s

    #  pass through to tools.sh which will error appropriately.
    tools.sh "$@"
    s=$?

    if [ $s -ne 0 ]; then
        echo "🦶ERROR: tools.sh failed with exit code $s" >&2
        return $s
    fi
}

function pipetest()
{
    # Sanity Check: If running interactively but no prompt provided, warn of potential hang
    if [ -t 0 ] && [[ "$*" != *"-i"* ]]; then
        echo "🦶pipetest: No user query detected in arguments; waiting for STDIN..." >&2
    fi

    local user_query="$*"

    # 1. Capture stdin into a temporary file – this allows very large input.
    local tmpdir tmpfile
    if ! tmpdir=$(mktemp -d 2>/dev/null) ; then
        printf >&2 "pipetest: could not create temporary directory\n"
        return 1
    fi
    trap 'rm -rf "$tmpdir"' EXIT
    if ! tmpfile=$(mktemp --tmpdir="$tmpdir" pipetest.XXXXXX 2>/dev/null) ; then
        printf >&2 "pipetest: could not create temporary file\n"
        return 1
    fi

    # 2. Read all of stdin into the temp file.
    cat >"$tmpfile"
    
    local reply
    local pager

    # Auto-detect the best available viewing tool
    if [ -n "${PIPETEST_PAGER}" ]; then
        pager="${PIPETEST_PAGER}"
    elif command -v batcat >/dev/null 2>&1; then
        pager="batcat --style=numbers,grid"
    elif command -v bat >/dev/null 2>&1; then
        pager="bat --style=numbers,grid"
    else
        pager="cat"
    fi
    
    # Render file content directly to stderr
    ${pager} "$tmpfile" 1>&2
    
    # Safe interactive prompt from /dev/tty (avoids the racing subshell read)
    read -r -p "🤖 ${user_query}: Y or N? " reply < /dev/tty
    
    printf "\n" 1>&2
    case "${reply,,}" in 
        y*)
            cat "$tmpfile"
        ;;
        *)
            printf "🚫 discarded\n" 1>&2
        ;;
    esac
}

# use `builtin help` if you want native bash help command
help () 
{ 
    help.sh "$@"
}
