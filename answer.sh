#!/usr/bin/env bash

# Ensure functions are available
SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE}")")"
source "${SCRIPT_DIR}/functions.sh"

TEE_MODE=""
if [ "$1" = "--tee" ] || [ "$1" = "-t" ]; then
    TEE_MODE="1"
    shift
fi

if [ -t 0 ] && [ -n "${ANSWER}" ]; then
    json="$(printf "%s" "${ANSWER}")"
else
    json="$(cat)"
fi

# Use the infer function defined in functions.sh
json=$(infer "$json")

if [ -n "$TEE_MODE" ]; then
    # Mid-pipeline: text to stderr for human, JSON to stdout for next stage
    printf "%s" "$json" | jq -r '.[-1].content' >&2
    printf "%s\n" "$json"
else
    printf "%s" "$json" | jq -r '.[-1].content'
fi
