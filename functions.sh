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
    local header_line
    local is_attachment=false
    local has_stdin=false

    # 1. Determine if we are in "Attachment" mode via flags
    for arg in "${ARGS[@]}"; do
        if [[ "$arg" == "-i" ]] || [[ "$arg" == "--input" ]]; then
            is_attachment=true
            break
        fi
    done

    # 2. Check if stdin has data WITHOUT consuming it yet
    # We use 'read -t' to check availability without blocking/hanging
    if read -r -t 0.1 header_line <&0; then
        has_stdin=true
        # If there is a magic header, consume the line and prepare content
        if [ "$header_line" = "${PIPELINE_MAGIC_HEADER}" ]; then
            echo "🦶ask: continuing conversation from stdin (magic header detected)" >&2
            RAW_INPUT="${header_line}$(printf '\n')$(cat)"
        else
            # It's raw data. Rewind/re-read logic is tricky in Bash, 
            # so we capture everything into a variable immediately.
            if [ "$is_attachment" = true ]; then
                echo "🦶ask: reading attachment from stdin" >&2
                RAW_INPUT="${header_line}$(printf '\n')$(cat)"
            else
                echo "🦶ask: prepending piped data to prompt" >&2
                RAW_INPUT="${header_line}$(printf '\n')$(cat)"
            fi
        fi
    fi

    # 3. LOGIC FIX: If no stdin AND (no -i and no arguments), don't hang/exit, just exit or wait?
    # Based on your requirement: "if there is no -i and no stdin do not wait for stdin."
    if [ "$has_stdin" = false ] && [ "$is_attachment" = false ] && [ $# -eq 0 ]; then
        exit 0
    fi

    # 4. Execute the command
    local nascent=""
    if [ -n "$RAW_INPUT" ]; then
        nascent=$(echo "$RAW_INPUT" | ask.sh "${ARGS[@]}")
    else
        # If we have no stdin but they provided an argument (e.g., `ask "hello"`)
        # or if it's a non-interactive call that is empty, run normally.
        nascent=$(ask.sh "${ARGS[@]}")
    fi

    local s=$?
    [ $s -ne 0 ] && { echo "🦶ask ERROR: ask.sh failed: $s" >&2; return 1; }

    if [ -t 1 ]; then
        echo "🦶ask: calling answer" >&2
        answer <<< "${nascent}"
    else
        printf "%s\n" "${nascent}"
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

function pipetest() {
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

    # 3. Prompt from stderr (visible in the terminal) and read a full line.
    local reply
    (printf "🦶"; head -10 "$tmpfile"; printf "🦶%s: Y or N? " "$user_query") >&2
    # Read from the actual terminal
    read -r reply < /dev/tty
    printf "\n" >&2

    # 4. If the first character is 'y' or 'Y', output the captured data.
    case "${reply}" in
        y*|Y*)
            cat "$tmpfile"
            ;;
        *)
            printf "🚫 discarded\n" >&2
            return 1
            ;;
    esac
}
