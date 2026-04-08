# source this file to define the functions

# Check if ask.sh is available
if ! command -v ask.sh &> /dev/null; then
    echo "$0: $(date) WARN: ask.sh is not on the PATH.  Please add the directory containing ask.sh to your PATH environment variable." >&2
fi

ask ()
{
    ANSWER=$(ask.sh "$@")
    if [ $? -ne 0 ]; then
      echo "$0: $(date) ERROR: ask.sh failed with exit code $?" >&2
      return 1
    fi
    printf "%s\n" "${ANSWER}"
}

answer ()
{
    answer.sh "$@"
    if [ $? -ne 0 ]; then
        echo "$0: $(date) ERROR: answer.sh failed with exit code $?" >&2
        return 1
    fi
}

bx ()
{
    bx.sh "$@"
    if [ $? -ne 0 ]; then
        echo "$0: $(date) ERROR: bx.sh failed with exit code $?" >&2
        return 1
    fi
}

unfence ()
{
    unfence.sh "$@"
    if [ $? -ne 0 ]; then
        echo "$0: $(date) ERROR: unfence.sh failed with exit code $?" >&2
        return 1
    fi
}
tools ()
{
    tools.sh "$@"
    if [ $? -ne 0 ]; then
        echo "$0: $(date) ERROR: tools.sh failed with exit code $?" >&2
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
    local tmpfile
    if ! tmpfile=$(mktemp --tmpdir="$(mktemp -d)" pipetest.XXXXXX 2>/dev/null) ; then
        printf >&2 "pipetest: could not create temporary file\n"
        exit 1
    fi
    trap 'rm -f "$tmpfile"' EXIT

    cat >"$tmpfile"


    # 3. Prompt from stderr (visible in the terminal) and read a full line.
    local reply
    (printf "🤖 "; head -10 "$tmpfile"; printf "🤖 %s: Y or N? " "$user_query") >&2 
    read -r -t 0 -s reply < /dev/tty     # non‑blocking: only keep the first char
    # If the first char is not a 'y'/'Y', read the rest of the line to discard it.
    if [[ ! "${reply}" =~ ^[yY]$ ]] ; then
        # Drain the remainder of the line (including the newline)
        read -r reply < /dev/tty
    fi
    printf "\n" >&2

    # 4. If the first character is 'y' or 'Y', output the captured data.
    case "${reply,,}" in
        y*) cat "$tmpfile" ;;
        *) printf "🚫 discarded\n" >&2 ;;
    esac
}
