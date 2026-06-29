#!/usr/bin/env -S bash
SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE}")")"
source "${SCRIPT_DIR}/env.sh"
source "${SCRIPT_DIR}/logging.sh"
source "${SCRIPT_DIR}/functions.sh"

PIPELINE_MAGIC_HEADER="Content-Type: application/x-llm-history+json"

# 1. Read stdin and pass through the core infer engine to guarantee a resolved state.
if ! resolved_history=$(_infer); then
  log_error "Inference failed."
  exit 1
fi

# 2. Extract strictly the text string content of the final assistant response.
assistant_text=$(jq -r '.[-1].content // empty' <<< "$resolved_history")

if [ -z "$assistant_text" ] || [ "$assistant_text" = "null" ]; then
  log_error "Cannot extract assistant message content."
  exit 1
fi

# 3. Always output raw text.
if [ -t 1 ]; then
  # EOL Terminal Window: Print a newline to clear the emojis, then print the Markdown response.
  printf '\n%s\n' "$assistant_text"
else
  # Inside a pipeline: Pipe the raw text string directly to downstream utilities.
  printf '%s\n' "$assistant_text"
fi
