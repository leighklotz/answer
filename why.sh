#!/usr/bin/env -S bash

SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE}")")"
source "${SCRIPT_DIR}/env.sh"
source "${SCRIPT_DIR}/logging.sh"
source "${SCRIPT_DIR}/functions.sh"

# Require stdin so interactive invocation fails fast instead of blocking.
if [ -t 0 ]; then
  log_and_exit 1 "No stdin detected. Pipe conversation history or input text into answer."
fi
# 
# Skip inference as we are looking for last inference.

# 3. Print a newline to stderr to move the cursor past the cache icons 
# before the final output is printed to stderr console.
  if [ -t 1 ]; then
    printf '\n' >&2
  fi

# Extract strictly the text string of the reasoning_content of the final assistant response.
  assistant_text="$(jq -r '.choices[0].message.reasoning_content | select (. != null) | tostring // empty')"

if [ -z "$assistant_text" ] || [ "$assistant_text" = "null" ]; then
  log_and_exit 1 "Cannot extract assistant message reasoning_content."
fi

# By default, output assistant text to stdout.
if [ -t 1 ]; then
  printf '%s\n' "$assistant_text"
else
  # Inside a pipeline
  printf '%s\n' "$assistant_text"
fi
