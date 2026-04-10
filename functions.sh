# for now, rely on AAA and parameters and this other package
source ~/wip/llamafiles/scripts/env.sh

# source this file to define the functions

# Require bash 4+
if [ "${BASH_VERSINFO[0]}" -lt 4 ]; then
    echo "$0: ERROR: bash 4 or later is required (running ${BASH_VERSION})." >&2
    return 1 2>/dev/null || exit 1
fi

# Check if ask.sh is available
if ! command -v ask.sh &> /dev/null; then
    echo "$0: $(date) WARN: ask.sh is not on the PATH.  Please add the directory containing ask.sh to your PATH environment variable." >&2
fi

function ask ()
{
    ask.sh "$@"
}

function answer ()
{
    answer.sh "$@"
    if [ $? -ne 0 ]; then
        echo "$0: $(date) ERROR: answer.sh failed with exit code $?" >&2
        return 1
    fi
}

function bx ()
{
    bx.sh "$@"
    if [ $? -ne 0 ]; then
        echo "$0: $(date) ERROR: bx.sh failed with exit code $?" >&2
        return 1
    fi
}

function unfence ()
{
    unfence.sh "$@"
    if [ $? -ne 0 ]; then
        echo "$0: $(date) ERROR: unfence.sh failed with exit code $?" >&2
        return 1
    fi
}

function tools ()
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
    local user_query="$@"

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

function infer ()
{
    local json="$1"
    
    # 1. Check if input is JSON array
    local is_json
    is_json=$(printf "%s" "$json" | tr -d '[:space:]' | cut -c1)

    if [ "$is_json" != "[" ]; then
        # Input is plain text, wrap it as a user message
        json=$(jq -n --arg content "$json" '[{"role":"user","content":$content}]')
    fi
    
    # 2. API Setup
    local api_key="${OPENAI_API_KEY:-}"
    local endpoint="${VIA_API_CHAT_BASE}/v1/chat/completions"

    # 3. Perform API call (The logic moved from ask.sh)
    local response
    response=$(curl -s -X POST "${endpoint}" \
        -H "Authorization: Bearer $api_key" \
        -H "Content-Type: application/json" \
        -d "$(jq -n --argjson messages "$json" \
        --arg model "gpt-3.5-turbo" \
        --argjson temperature 0.7 \
        --argjson max_tokens 4096 \
        '{model: $model, mode: "instruct", temperature: $temperature, max_tokens: $max_tokens, messages: $messages}')")

    local assistant_reply
    assistant_reply=$(jq -r '.choices[0].message.content // empty' <<< "$response")

    if [ -z "$assistant_reply" ]; then
      printf "No response received from the API.\n" >&2
      return 1
    fi

    # 4. Append reply and return updated JSON
    local new_assistant_message
    new_assistant_message=$(jq -n --arg content "$assistant_reply" '{"role":"assistant","content":$content}')
    jq --argjson reply "$new_assistant_message" '. + [$reply]' <<< "$json"
}
