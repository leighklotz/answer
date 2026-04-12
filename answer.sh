#!/usr/bin/env -S bash

TEE_MODE=""
NO_DECORATE=""
PIPELINE_MAGIC_HEADER="Content-Type: application/x-llm-history+json"

# arg parsing loop
while [[ $# -gt 0 ]]; do
    case "$1" in
        --tee|-t)
            TEE_MODE="1"
            shift
            ;;
        *)
            echo "Usage: $0 [--tee | -t]" >&2
            echo "$0: unknown argument $1" >&2
            exit 1
            ;;
    esac
done

# Read stdin and extract JSON context or raw input
if [ ! -t 0 ]; then
    raw_input=$(cat)
    if [[ "$raw_input" == "${PIPELINE_MAGIC_HEADER}"* ]]; then
        # We received a Conversation State (Header + JSON body)
        json="${raw_input#$PIPELINE_MAGIC_HEADER}"
        json="${json#$'\n'}"
    else
        # We received raw text or un-headered JSON
        json="$raw_input"
    fi
else
    # No stdin (direct call)
    json="[]"
fi

# Extract the content of the very last message in the history array
last_content=$(printf "%s\n" "$json" | jq -r 'if type == "array" and length > 0 then .[-1].content else . end' 2>/dev/null)

if [ -n "$TEE_MODE" ]; then
    # CASE: OBSERVATION MODE (answer -t)
    # Print human-readable text to stderr, pass JSON history through stdout.
    printf "%s\n" "$last_content" >&2
    printf "%s\n%s\n" "${PIPELINE_MAGIC_HEADER}" "$json"
elif [ ! -t 1 ]; then
    # CASE: TOOL/EXTRACTION MODE (ask | answer | tool)
    # Convert heavy JSON history into light Plain Text for the next command in pipe.
    printf "%s\n" "$last_content"
else
    # CASE: TERMINAL OUTPUT (direct call 'answer' or end of line)
    # Just print the text to the user.
    printf "%s\n" "$last_content"
fi
