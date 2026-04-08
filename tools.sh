#!/usr/bin/env bash

# tools.sh — pipeline-compatible wrapper around toolex
# Usage: ask "prompt" | tools <module> [<module>...] | answer
#
# Reads a JSON conversation array from stdin, passes it to toolex.py in
# --pipe mode (which resolves tool calls and returns the updated conversation
# array), and writes the result to stdout.

TOOLEX_SH=~/wip/toolex/toolex.sh

if [ $# -eq 0 ]; then
    echo "Usage: tools <module_name> [<module_name>...]" >&2
    exit 1
fi

if [ -t 0 ]; then
    echo "tools: expected JSON conversation array on stdin" >&2
    exit 1
fi

if ! command -v toolex.py &> /dev/null; then
    echo "tools: toolex.py not found on PATH. Please install toolex." >&2
    exit 1
fi

# Build --tools flags
TOOLS_ARGS=()
for module in "$@"; do
    TOOLS_ARGS+=("--tools" "$module")
done

# Pass through to toolex in pipe mode:
# toolex.py --pipe reads JSON conversation from stdin, writes updated JSON to stdout
exec "${TOOLEX_SH} --pipe "${TOOLS_ARGS[@]}"
