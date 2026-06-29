#!/usr/bin/env -S bash
SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE}")")"
source "${SCRIPT_DIR}/env.sh"
source "${SCRIPT_DIR}/logging.sh"
source "${SCRIPT_DIR}/functions.sh"

PIPELINE_MAGIC_HEADER="Content-Type: application/x-llm-history+json"

# 1. Require stdin so interactive invocation fails fast instead of blocking.
if [ -t 0 ]; then
  log_and_exit 1 "No stdin detected. Pipe conversation history or input text into answer."
fi

# 2. Read stdin and pass through the core infer engine to guarantee a resolved state.
if ! resolved_history=$(_infer); then
  log_and_exit 1 "Inference failed."
fi

# 3. Extract strictly the text string content of the final assistant response.
assistant_text=$(jq -r '.[-1].content // empty' <<< "$resolved_history")

if [ -z "$assistant_text" ] || [ "$assistant_text" = "null" ]; then
  log_and_exit 1 "Cannot extract assistant message content."
fi

# 4. Always output raw text.
if [ -t 1 ]; then
  # EOL Terminal Window: Print a newline to clear the emojis, then print the Markdown response.
  printf '\n%s\n' "$assistant_text"
else
  # Inside a pipeline: Pipe the raw text string directly to downstream utilities.
  printf '%s\n' "$assistant_text"
fi
