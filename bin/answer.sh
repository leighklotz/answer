#!/usr/bin/env -S bash

SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE}")")"
source "${SCRIPT_DIR}/env.sh"
source "${SCRIPT_DIR}/logging.sh"
source "${SCRIPT_DIR}/functions.sh"

# Require stdin so interactive invocation fails fast instead of blocking.
if [ -t 0 ]; then
  log_and_exit 1 "No stdin detected. Pipe conversation history or input text into answer."
fi

TEE_MODE=0
JSON_MODE=0

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -t|--tee)
            TEE_MODE=1
            shift
            ;;
        -j|--json)
            JSON_MODE=1
            shift
            ;;
        *)
            break # Stop parsing if an unknown argument is found
            ;;
    esac
done

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
assistant_text=$(jq -r '.[-1].content | select (. != null) | tostring // empty' <<< "$resolved_history")

if [ -z "$assistant_text" ] || [ "$assistant_text" = "null" ]; then
  log_and_exit 1 "Cannot extract assistant message content."
fi

# --tee 
# If --tee is active, always output the text preview to stderr for human readability.
if [[ $TEE_MODE -eq 1 ]]; then
    printf '\n👕%s\n' "$assistant_text" >&2
fi

# stdout text/json
if [[ $JSON_MODE -eq 1 ]]; then
    # Output the full JSON conversation array preceded by the magic header for pipeline continuity.
    printf "%s\n%s\n" "${PIPELINE_MAGIC_HEADER}" "${resolved_history}"
else
    # Default: output only the raw plain text response to stdout.
    printf '%s\n' "$assistant_text"
fi
