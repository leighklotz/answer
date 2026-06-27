#!/usr/bin/env -S bash
SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE}")")"
source "${SCRIPT_DIR}/env.sh"
source "${SCRIPT_DIR}/logging.sh"
source "${SCRIPT_DIR}/functions.sh"

PIPELINE_MAGIC_HEADER="Content-Type: application/x-llm-history+json"

# 1. Read stdin and pass through the core infer engine to guarantee a resolved state
resolved_history=$(infer)

# In answer.sh, right after resolved_history=$(infer)
echo "DEBUG: resolved_history = $resolved_history" >&2

# 2. Extract strictly the text string content of the final assistant response
assistant_text=$(jq -r 'if type == "array" and length > 0 then .[-1].content else empty end' <<< "$resolved_history" 2>/dev/null)

if [ -z "$assistant_text" ]; then
  echo "Footanswer ERROR: Cannot extract assistant message content." >&2
  exit 1
fi

# 3. Always output raw text (no more history JSON leaks)
if [ -t 1 ]; then
  # EOL Terminal Window: Print a newline to clear the emojis, then print the Markdown response
  printf "\n%s\n" "$assistant_text"
else
  # Inside a pipe line: Pipe the raw text string directly to downstream utilities
  printf "%s\n" "$assistant_text"
fi
