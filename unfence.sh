#!/usr/bin/env -S bash -e

SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE}")")"
source "${SCRIPT_DIR}/env.sh"
source "${SCRIPT_DIR}/logging.sh"
source "${SCRIPT_DIR}/functions.sh"

input=$(cat)

# If stdin is an unresolved conversation, resolve it to assistant text first.
if [[ "$input" == "${PIPELINE_MAGIC_HEADER}"* ]]; then
  input=$(printf '%s\n' "$input" | "${SCRIPT_DIR}/answer")
fi

# Extract only the first fenced block.
awk '
  /^```$/ && flag { exit }
  /^```.*$/ && !flag { flag = 1; next }
  flag { print }
' <<< "$input"
