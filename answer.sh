#!/usr/bin/env bash

TEE_MODE=""
NO_DECORATE=""

# Fixed arg parsing loop
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
    # Use a check to prevent 'cat' from hanging if stdin is empty/not provided
    if [ ! -t 0 ]; then
        json="$(cat)"
    else
        json="[]"
    fi
fi

if [ -n "$TEE_MODE" ]; then
    # Mid-pipeline: text to stderr for human, JSON to stdout for next stage
    if [ -n "${NO_DECORATE}" ]; then
        printf "🤖 %s" "$json" | jq -r '.[-1].content' >&2
    else
        printf "%s" "$json" | jq -r '.[-1].content' >&2
    fi
    # Note: You likely want to output the actual JSON to stdout here 
    # so it can be piped to the next stage, e.g.: echo "$json"
    printf "%s\n" "$json"
else
    # Terminal: just print the text
    printf "%s" "$json" | jq -r '.[-1].content'
fi
