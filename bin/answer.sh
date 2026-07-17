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

if [[ "$1" == "--tee" || "$1" == "-t" ]]; then
    TEE_MODE="1"; shift
else
    TEE_MODE=""; shift
fi

# Read stdin and pass through the core infer engine to guarantee a resolved state.
  if ! resolved_history=$(cat | _infer); then
    log_and_exit 1 "Inference failed."
  fi

# Print a newline to stderr to move the cursor past the cache icons 
# before the final output is printed to stderr console.
  if [ -t 1 ]; then
    printf '\n' >&2
  fi

# Extract strictly the text string content of the final assistant response.
# echo "resolved_history=$resolved_history"
  assistant_text=$(jq -r '.[-1].content | select (. != null) | tostring // empty' <<< "$resolved_history")

if [ -z "$assistant_text" ] || [ "$assistant_text" = "null" ]; then
  log_and_exit 1 "Cannot extract assistant message content."
fi

# Output assistant text to stdout.
# If inside a pipeline and --tee, duplicate output to stderr
if [[ ! -t 1 ]] && [[ -n "$TEE_MODE" ]]; then
    printf '\n👕%s\n' "$assistant_text" >&2
  fi
printf '%s\n' "$assistant_text"

