#!/usr/bin/env bash

# tools.sh — pipeline-compatible wrapper around toolex
# Usage: ask "prompt" | tools <module> [<module>...] | answer
#
# Reads a JSON conversation array from stdin, passes it to toolex.py in
# --pipe mode (which resolves tool calls and returns the updated conversation
# array), and writes the result to stdout.

SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE}")")"
source "${SCRIPT_DIR}/env.sh"
source "${SCRIPT_DIR}/logging.sh"
source "${SCRIPT_DIR}/functions.sh"

TOOLEX_SH=~/wip/toolex/toolex.sh

if [ $# -eq 0 ]; then
    echo "Usage: tools <module_name> [<module_name>...]" >&2
    exit 1
fi

if [ -t 0 ]; then
    echo "🦶tools: expected JSON conversation array on stdin" >&2
    exit 1
fi

# Build --tools flags
TOOLS_ARGS=()
for arg in "$@"; do
    if [[ "$arg" == -* ]]; then
        # It's a flag (like --debug), pass it through directly
        TOOLS_ARGS+=("$arg")
    else
        # It's a module name, wrap it with --tools
        TOOLS_ARGS+=("--tools" "$arg")
    fi
done

# toolex.py --pipe reads MIME+JSON conversation from stdin, writes updated MIME+JSON to stdout

if [ -t 1 ]; then
  # Contract Rule: If at EOL terminal, hand over to answer to print pristine markdown
  "${TOOLEX_SH}" "${TOOLS_ARGS[@]}" | "${SCRIPT_DIR}/answer"
else
  # Contract Rule: Inside a pipe, forward the updated full JSON history state
  "${TOOLEX_SH}" "${TOOLS_ARGS[@]}"
fi

