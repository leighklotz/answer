#!/usr/bin/env -S bash

SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE}")")"
source "${SCRIPT_DIR}/../env.sh"
source "${SCRIPT_DIR}/../logging.sh"
source "${SCRIPT_DIR}/../functions.sh"

# Require stdin so interactive invocation fails fast instead of blocking.
if [ -t 0 ]; then
    log_and_exit 1 "No stdin detected. Requires inference response."
fi

# Capture the input into a variable to allow multiple passes
input_data=$(cat)

# Extract strictly the text string of the reasoning_content of the final assistant response.
assistant_text=$(jq -r '.choices[0].message.content           | select (. != null)' <<< "$input_data")

printf "🧠\n" >&2
printf "%s\n" "$assistant_text"
