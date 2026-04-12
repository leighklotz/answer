# source this file to define the functionsg

# Require bash 4+
if [ "${BASH_VERSINFO[0]}" -lt 4 ]; then
    echo "$0: ERROR: bash 4 or later is required (running ${BASH_VERSION})." >&2
    return 1 2>/dev/null || exit 1
fi

# Check if ask.sh is available
if ! command -v ask.sh &> /dev/null; then
    echo "$0: $(date) WARN: ask.sh is not on the PATH.  Please add the directory containing ask.sh to your PATH environment variable." >&2
fi

declare -g LAST_ANSWER

PIPELINE_MAGIC_HEADER="Content-Type: application/x-llm-history+json"

ask ()
{
    local RAW_JSON
    local FLAG
    local header_line

    # If stdin is available, check for PIPELINE_MAGIC_HEADER:
    # If header is present pass through raw JSON, else if stdin is available and header is absent, pass ask -i.
    FLAG=""
    echo "about read -t" >&2
    if read -t 0.001 header_line; then
        printf "** cat %s\n" "${header_line}" >&2
        if [ "$header_line" = "${PIPELINE_MAGIC_HEADER}" ]; then
            echo "Saw PIPELINE_MAGIC_HEADER" >&2
            else
            FLAG="-i"
            printf "Saw random file input: %s\n" "${header_line}" >&2
        fi
    fi
    if [ -t 1 ]; then
        echo "* t1">&2
        # 1. If output is a terminal, run ask.sh and capture output into a variable pass to answer
        # 2. Calling 'answer' in the CURRENT shell using a here-string (<<<) avoids a pipe and ensures LAST_ANSWER is updated globally.
        answer <<< "$(printf "%s\n" "${header_line}"; cat | ask.sh $FLAG "$@")"; s=$?
        return 33
    else
        echo "* t0">&2
        # 3. If output is not a terminal, run ask.sh in a subshell and capture output into a variable
        ask.sh $FLAG "$@"; s=$?
    fi
    # Check if the command failed
    if [ $? -ne 0 ]; then
        echo "$0: $(date) ERROR: ask.sh failed: $s" >&2
        return 1
    fi
}

answer ()
{
    if [ -t 1 ] && [ -n "${LAST_ANSWER}" ]; then
        printf "%s\n" "${LAST_ANSWER}"
        return 0
    fi

    local ANSWER
    ANSWER="$(answer.sh "$@")"
    s=$?
    if [ $s -ne 0 ]; then
        echo "$0: $(date) ERROR: answer.sh failed with exit code $s" >&2
        return 1
    fi

    printf "%s\n" "${ANSWER}"

    if [ "$1" = "--tee" ] || [ "$1" = "-t" ]; then
        # skip setting last-answer when answer is used mid-pipeline?
        # or keep it separate, maybe?
        # also do we keep inputs as well as outputs?
        # need cache strategy for repeatable clis
        # echo "debug: Not setting LAST_ANSWER in $0 ${@}" >&2
        true
    else
        # echo "debug: Setting LAST_ANSWER[$$] to $ANSWER" >&2
        export LAST_ANSWER="${ANSWER}"
    fi
}

bx ()
{
    bx.sh "$@"
    s=$?
    if [ $s -ne 0 ]; then
        echo "$0: $(date) ERROR: bx.sh failed with exit code $s" >&2
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

tools ()
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
    local user_query="$*"  #is this right vs "$@"?

    # 1. Capture stdin into a temporary file – this allows very large input.
    local tmpdir tmpfile
    if ! tmpdir=$(mktemp -d 2>/dev/null) ; then
        printf >&2 "pipetest: could not create temporary directory\n"
        exit 1
    fi
    trap 'rm -rf "$tmpdir"' EXIT
    if ! tmpfile=$(mktemp --tmpdir="$tmpdir" pipetest.XXXXXX 2>/dev/null) ; then
        printf >&2 "pipetest: could not create temporary file\n"
        exit 1
    fi

    # 2. Read all of stdin into the temp file.
    cat >"$tmpfile"

    # 3. Prompt from stderr (visible in the terminal) and read a full line.
    local reply
    (printf "🤖 "; head -10 "$tmpfile"; printf "🤖 %s: Y or N? " "$user_query") >&2
    read -r reply < /dev/tty
    printf "\n" >&2

    # 4. If the first character is 'y' or 'Y', output the captured data.
    case "${reply}" in
        y*|Y*) cat "$tmpfile" ;;
        *) printf "🚫 discarded\n" >&2 ;;
    esac
}
