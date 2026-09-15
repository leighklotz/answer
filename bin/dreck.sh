#!/usr/bin/env -S bash -x

# ---------------------
# 📌 Overview
# ---------------------
#
# This script compares two files (fn1 and fn2) using an LLM to evaluate if the
# second file is a quality summary of the first. It supports custom prompts via
# optional arguments and skips files with special headers (e.g., code fences).
#
# Usage:
#   dreck [fn1] [fn2] -- "additional prompt words"
#   dreck [fn1] [fn2]
#   dreck # (for interactive input, e.g., git diff, lx output)

# ---------------------
# 📌 Configuration
# ---------------------
PROMPT="Perform a rigorous comparison between these two files.
0) If the file is JSON, empty, binary data, etc. report that fact and stop immediately.
1) Detect any 'LLM dreck' in the second file (unnecessary conversational intro/outro or boilerplate).
2) Check for lazy elisions—ensure no critical content from the first file was omitted, summarized away, or truncated in the second version.
3) Conclude if the changes represent a substantive improvement in quality and completeness."

USER_PROMPT=""  # For user-provided prompts after '--'

# ---------------------
# 📌 Core Functions
# ---------------------
# Source supporting modules (ensure they are available)
SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE}")")"
source "${SCRIPT_DIR}/env.sh"
source "${SCRIPT_DIR}/logging.sh"
source "${SCRIPT_DIR}/functions.sh"

# ---------------------
# 📌 Argument Parsing
# ---------------------
# Parse the command line for -- and optional prompt words
ARGS=("$@")
ARG_COUNT=${#ARGS[@]}
INDEX=0

while (( INDEX < ARG_COUNT )); do
    if [[ "${ARGS[$INDEX]}" == "--" ]]; then
        # Collect all remaining arguments as user-supplied prompt
        USER_PROMPT="${ARGS[@]:$((INDEX + 1))}"
        break
    fi
    ((INDEX++))
done

# ---------------------
# 📌 File Comparison Logic
# ---------------------
if [[ -n "$1" ]] && [[ -n "$2" ]]; then
    # Check if files are identical
    if cmp --quiet "$1" "$2"; then
        log_info "Files are identical."
        exit 0
    fi

    # Skip files starting with code fences
    if [[ "$(head -1 "$2")" == '```'* ]]; then
        log_info "File $2 starts with code fence; not going further."
        exit 1
    fi

    # Skip files starting with an 'lx' header
    if [[ "$(head -1 "$2")" == '# file '* ]]; then
        log_info "File $2 looks like it starts with an 'lx' file header; not going further."
        exit 1
    fi

    # Append user-supplied prompt to main prompt
    PROMPT="$PROMPT $USER_PROMPT"

    # Run comparison using lx and ask
    lx "$1" "$2" | ask "$@" "$PROMPT"
else
    # No file arguments: use default prompt and prompt the user
    PROMPT="$PROMPT $USER_PROMPT"
    ask "$@" "$PROMPT"
fi
