#!/usr/bin/env bash

# tools.sh - pipeline-compatible wrapper around toolex
# Usage: ask "prompt" | tools [options] <module> [<module...>] | answer

SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
source "${SCRIPT_DIR}/env.sh"
source "${SCRIPT_DIR}/logging.sh"
source "${SCRIPT_DIR}/functions.sh"

# Configuration defaults
: "${TOOLEX_SH:=$HOME/wip/toolex/toolex.sh}"
: "${TOOLS_FLAGS:=}"
DEFAULT_LOGLEVEL="INFO" # Fallback if not specified via command line

if [ $# -eq 0 ] || [[ "$*" == *"--help"* ]] || [[ "$*" == *"-h"* ]]; then
    echo "Usage:" >&2
    echo "  tools [options] <module> [<module...>]" >&2
    echo "" >&2
    echo "Examples:" >&2
    echo "  tools git bash                           # Enable modules 'git' and 'bash'" >&2
    echo "  tools --log-level DEBUG file:read=*.py   # Set log level AND restrict files" >&2
    exit 1
fi

if [ -t 0 ]; then
    log_and_exit 1 "expected JSON conversation array on stdin"
fi

EXTRA_FLAGS=()
TOOLS_ARGS=()

# Parse arguments: distinguish between flags (starting with '-') and tool specs
while [[ $# -gt 0 ]]; do
    if [[ "$1" == -* ]]; then
        # It's an option/flag (e.g., --log-level or --workspace-dir)
        EXTRA_FLAGS+=("$1")
        shift
        # If the next argument exists and doesn't start with '-', 
        # it is a value for this flag (like 'DEBUG')
        if [[ $# -gt 0 && ! "$1" == -* ]]; then
            EXTRA_FLAGS+=("$1")
            shift
        fi
    else
        # It's a module or capability spec; wrap it in --tools
        TOOLS_ARGS+=(--tools "$1")
        shift
    fi
done

# Set the log level for Python: 
# If user provided --log-level, use that. Otherwise, use default logic from original script.
if [[ " ${EXTRA_FLAGS[*]} " == *"--log-level"* ]]; then
    LOGLEVEL="" # User already passed it via EXTRA_FLAGS
else
    [[ -n "$DEBUG" ]] && LOGLEVEL="--log-level=DEBUG" || LOGLEVEL="--log-level=${DEFAULT_LOGLEVEL}"
fi

# Prepare the final call array (Flags + Tool Specs)
FINAL_ARGS=("${EXTRA_FLAGS[@]}" "${TOOLS_ARGS[@]}")

if [ -t 1 ]; then
    log_trace "Calling ${TOOLEX_SH} $TOOLS_FLAGS ${FINAL_ARGS[*]} with log level: ${LOGLEVEL}"
    # Note: We pipe to answer ONLY if in a TTY-like environment as per original logic, 
    # but usually tools are used in pipes where -t 1 is false.
    if [ -n "$TRACE" ]; then
        tee /dev/stderr | "${TOOLEX_SH}" $TOOLS_FLAGS "${FINAL_ARGS[@]}" $LOGLEVEL | "${SCRIPT_DIR}/answer"
    else
        "${TOOLEX_SH}" $TOOLS_FLAGS "${FINAL_ARGS[@]}" $LOGLEVEL | "${SCRIPT_DIR}/answer"
    fi
else
    # If stdin is a pipe, we just run the engine (the 'answer' part of your pipeline 
    # usually handles the piping/output in these complex chains)
    "${TOOLEX_SH}" $TOOLS_FLAGS "${FINAL_ARGS[@]}" $LOGLEVEL
fi
