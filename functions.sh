# source this file to define the functions

# Require bash 4+
if [ "${BASH_VERSINFO[0]}" -lt 4 ]; then
    echo "$0: ERROR: bash 4 or later is required (running ${BASH_VERSION})." >&2
    return 1 2>/dev/null
fi

# Check if ask.sh is available
if ! command -v ask.sh &> /dev/null; then
    echo "$0: $(date) WARN: ask.sh is not on the PATH.  Please add the directory containing ask.sh to your PATH environment variable." >&2
fi

declare -g LAST_ANSWER
PIPELINE_MAGIC_HEADER="Content-Type: application/x-llm-history+json"

function ask ()
{
    local RAW_JSON
    local FLAG
    local header_line

    # If stdin is available, check for PIPELINE_MAGIC_HEADER:
    # If header is present pass through raw JSON, else if stdin is available and header is absent, pass ask -i.
    FLAG=""
    if [ -t 0 ]; then
        # Stdin is a terminal, no piped data expected via stdin usually
        true
    elif read -t 0.1 header_line; then
        if [ "$header_line" = "${PIPELINE_MAGIC_HEADER}" ]; then
            echo "🦶ask: continuing conversation from stdin" >&2
            # Since we already read the header, use 'cat' to get the remaining JSON body
            RAW_JSON=$(cat)
        else
            echo "🦶ask: reading attachment from stdin" >&2
            FLAG="-i"
            # Combine the line we just read with the rest of the stream
            RAW_JSON="${header_line}$(printf '\n')"
            RAW_JSON+="$(cat)"
        fi
    fi

    if [ -n "$RAW_JSON" ] || [ "$FLAG" = "-i" ]; then
        nascent="$(printf "%s\n" "${RAW_JSON}" | ask.sh $FLAG "$@")"
    else
        # No stdin data was found, run normally without a pipe
        nascent="$(ask.sh "$@")"
    fi

    s=$?
    # Check if the command failed
    if [ $s -ne 0 ]; then
        echo "* ask() $(date) ERROR: ask.sh failed: $s" >&2
        return 1
    fi

    if [ -t 1 ]; then
        # 1. If output is a terminal, run ask.sh and capture output into a variable pass to answer
        # 2. Calling 'answer' in the CURRENT shell using a here-string (<<<) avoids a pipe and ensures LAST_ANSWER is updated globally.
        answer <<< "${nascent}"
        s=$?
        # printf "done calling answer, LAST_ANSWER=%s\n" "${LAST_ANSWER}" >&2
        # Check if the command failed
        if [ $s -ne 0 ]; then
        echo "* ask() $(date) ERROR: answer failed: $s" >&2
        return 1
        fi
    else
        # 3. If output is not a terminal, run ask.sh in a subshell and capture output into a variable
        # Pass the reconstructed RAW_JSON via a pipe if not in terminal
        printf "%s\n" "${nascent}"
        s=0
    fi
}

function answer ()
{
    # Check if stdout is a terminal AND stdin is also a terminal 
    # (meaning the user called 'answer' directly with no input/pipe)
    if [ -t 1 ] && [ -t 0 ] && [ -n "${LAST_ANSWER}" ]; then
        printf "%s\n" "${LAST_ANSWER}"
        return 0
    fi

    local ANSWER
    ANSWER="$(answer.sh "$@")"
    s=$?
    if [ $s -ne 0 ]; then
        echo "answer() $(date) ERROR: answer.sh failed with exit code $s" >&2
        return 1
    fi

    printf "%s\n" "${ANSWER}"

    if [ "$1" = "--tee" ] || [ "$1" = "-t" ]; then
        # skip setting last-answer when answer is used mid-pipeline?
        # or keep it separate, maybe?
        # also do we keep inputs as well as outputs?
        # need cache strategy for repeatable clis
        # echo "answer() debug: Not setting LAST_ANSWER in $0 ${@}" >&2
        printf "* answer() not setting LAST_ANSWER\n" >&2
        true
    else
        # echo "answer() debug: Setting LAST_ANSWER[$$] to $ANSWER" >&2
        if [ -n "${LAST_ANSWER}" ] && [ "${LAST_ANSWER}" != 'null' ]; then
             printf "answer() * setting LAST_ANSWER\n" >&2
             export LAST_ANSWER="${ANSWER}"
        fi
    fi
}

function bx ()
{
    local quiet
    while [[ $# -gt 0 ]]; do
        case "$1" in 
            -q) quiet=1; shift ;;
            -*) echo "bx: unknown option $1" >&2; return 1 ;;
            *) break ;;
        esac
    done
 
    bx.sh "$@"
    s=$?
    if [ $s -ne 0 ] && [ -z "${quiet}" ] ; then
        echo "bx: $(date) ERROR: bx.sh failed with exit code $s" >&2
        return 1
    fi
}

unfence ()
{
    unfence.sh "$@"
    s=$?
    if [ $s -ne 0 ]; then
        echo "$0: $(date) ERROR: unfence.sh failed with exit code $s" >&2
        return 1
    fi
}

function tools ()
{
    tools.sh "$@"
    s=$?
    if [ $s -ne 0 ]; then
        echo "$0: $(date) ERROR: tools.sh failed with exit code $s" >&2
        return 1
    fi
}

# pipetest alias - forward piped data after a Y/N confirmation
# Read all data from standard input (the "pipe").
# Ask the user "Y or N? " (case‑insensitive, newline required).
# If the answer starts with "y" (or "yes") the data is forwarded
# to stdout.  Otherwise nothing is written.

function pipetest() {
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
