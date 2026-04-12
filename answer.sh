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
        --no-decorate|-n)
            NO_DECORATE="1"
            shift
            ;;
        *)
            echo "Usage: $0 [--tee | -t] [--no-decorate | -n]" >&2
            echo "$0: unknown argument $1" >&2
            exit 1
            ;;
    esac
done

if [ -t 0 ] && [ -n "${LAST_ANSWER}" ]; then
    json="$(printf "%s" "${LAST_ANSWER}")"
else
    if [ ! -t 0 ]; then
        raw_input=$(cat)
        # Strip header if present
        if [[ "$raw_input" == "${PIPELINE_MAGIC_HEADER}"* ]]; then
            # Remove the header string
            json="${raw_input#$PIPELINE_MAGIC_HEADER}"
            # Strip the leading newline that follows the header
            json="${json#$'\n'}"
        else
            json="$raw_input"
        fi
    else
        json="[]"
    fi
fi

if [ -n "$TEE_MODE" ]; then
    # CASE 1: User explicitly requested Tee mode.
    # Output text to stderr (for visibility) and JSON to stdout (for the pipeline).
    printf "%s\n" "$json" | jq -r '.[-1].content' >&2
    printf "%s\n%s\n" "${PIPELINE_MAGIC_HEADER}" "$json"
elif [ ! -t 1 ]; then
    # CASE 2: Mid-pipeline (stdout is a pipe) and NOT in tee mode.
    # We MUST output the header and JSON so the next 'ask' can continue the conversation.
    printf "%s\n%s\n" "${PIPELINE_MAGIC_HEADER}" "$json"
else
    # CASE 3: Terminal output (user is looking at the screen) and NOT in tee mode.
    # Just print the human-readable text.
    printf "%s\n" "$json" | jq -r '.[-1].content'
fi
