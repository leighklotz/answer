#!/usr/bin/env bash

# tools.sh - pipeline-compatible wrapper around toolex
# Usage: ask "prompt" | tools <module> [<module>...] | answer
#
# Reads a JSON conversation array from stdin, passes it to toolex.py in
# --pipe mode (which resolves tool calls and returns the updated conversation
# array), and writes the result to stdout.

# Example use case
# ask what branches are not merged into main | tools git
# For more info see https://github.com/leighklotz/toolex
#

SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE}")")"
source "${SCRIPT_DIR}/env.sh"
source "${SCRIPT_DIR}/logging.sh"
source "${SCRIPT_DIR}/functions.sh"

TOOLEX_SH=~/wip/toolex/toolex.sh

if [ $# -eq 0 ]; then
    echo "Usage: tools <module> [<module...>] [--args]" >&2
    exit 1
fi

if [ -t 0 ]; then
    echo "🦶tools: expected JSON conversation array on stdin" >&2
    exit 1
fi

# We prefix the user's arguments with --tools.
# Because of nargs='+' in Python, everything provided after this 
# will be consumed as tools until another flag (e.g., --log-level) is hit.
# toolex.py reads MIME+JSON conversation from stdin, writes updated MIME+JSON to stdout
if [ -t 1 ]; then
  "${TOOLEX_SH}" --tools "$@" | "${SCRIPT_DIR}/answer"
else
  "${TOOLEX_SH}" --tools "$@"
fi
