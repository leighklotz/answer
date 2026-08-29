#!/usr/bin/env bash

# tools.sh - pipeline-compatible wrapper around toolex
# Usage: ask "prompt" | tools <module> [<module>...] | answer
#
# Reads a JSON conversation array from stdin, passes it to toolex.py in
# --pipe mode (which resolves tool calls and returns the updated conversation
# array), and writes the result to stdout.

SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
source "${SCRIPT_DIR}/env.sh"
source "${SCRIPT_DIR}/logging.sh"
source "${SCRIPT_DIR}/functions.sh"

: "${TOOLEX_SH:=$HOME/wip/toolex/toolex.sh}"
: "${TOOLS_FLAGS:=}"

if [ $# -eq 0 ] || [ "$1" == "--help" ] || [ "$1" == "-h" ]; then
    echo "Usage: tools <module> [<module...>]" >&2
    exit 1
fi

if [ -t 0 ]; then
    log_and_exit 1 "expected JSON conversation array on stdin"
fi

TOOLS_ARGS=()
for spec in "$@"; do
    TOOLS_ARGS+=(--tools "$spec")
done

if [ -t 1 ]; then
    log_trace "Calling ${TOOLEX_SH} $TOOLS_FLAGS ${TOOLS_ARGS[*]}"
    if [ -n "$TRACE" ]; then
        tee /dev/stderr | "${TOOLEX_SH}" $TOOLS_FLAGS "${TOOLS_ARGS[@]}" | "${SCRIPT_DIR}/answer"
    else
        "${TOOLEX_SH}" $TOOLS_FLAGS "${TOOLS_ARGS[@]}" | "${SCRIPT_DIR}/answer"
    fi
else
    "${TOOLEX_SH}" $TOOLS_FLAGS "${TOOLS_ARGS[@]}"
fi
