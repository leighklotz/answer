#!/usr/bin/env -S bash
SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE}")")"
source "${SCRIPT_DIR}/env.sh"
source "${SCRIPT_DIR}/logging.sh"
source "${SCRIPT_DIR}/functions.sh"

PIPELINE_MAGIC_HEADER="Content-Type: application/x-llm-history+json"

# --- ARGUMENT PARSING ---
USE_SYSTEM_MSG=false
PLAIN_INPUT=""
TEE_MODE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    -i|--input) PLAIN_INPUT="1"; shift ;;
    --use-system-message) USE_SYSTEM_MSG=true; shift ;;
    --tee|-t) TEE_MODE="1"; shift ;;
    --help) usage; exit 0 ;;
    *) break ;;
  esac
done

prompt="$*"

# --- INPUT HANDLING & HISTORY BUILDING ---
if [ ! -t 0 ]; then
  stdin_content=$(cat)
  first_char=$(echo "$stdin_content" | head -c 1 | tr -d '[:space:]')
  
  is_json=false
  if [ "$first_char" = "[" ] || echo "$stdin_content" | grep -q "^${PIPELINE_MAGIC_HEADER}" ; then
    is_json=true
  fi

  if [ "$PLAIN_INPUT" = "1" ]; then
    messages=$(jq -n --arg p "$prompt" --arg c "$stdin_content" '[{role:"user", content: ($p + "\n\nATTACHMENT:\n" + $c)}]')
  elif [ "$is_json" = true ]; then
    # MODE: Conversation History (JSON)
    # 1. Native header strip to avoid sed slash collisions completely
    clean_stdin="${stdin_content#${PIPELINE_MAGIC_HEADER}}"
    clean_stdin="${clean_stdin#$'\n'}"

    # 2. Resolve the previous turn cleanly
    # FIX: Capture stderr separately to ensure clean_stdin is pure JSON
    log_info "0. TEE_MODE=$TEE_MODE messages=${messages//$'\n'/\\n}"
    clean_stdin=$(infer <<< "$clean_stdin" 2>/dev/null)

    # FIX: Validate JSON output from infer
    if ! jq -e '.' <<< "$clean_stdin" >/dev/null 2>&1; then
        echo "🦶ask: WARN: infer returned invalid JSON, resetting state." >&2
        clean_stdin="[]"
    fi

    # 3. Append your new user prompt directly to the clean conversation history array
    if [ -n "$prompt" ]; then
      new_msg=$(jq -n --arg p "$prompt" '{"role":"user","content":$p}')
      messages=$(jq -c --argjson n "$new_msg" --argjson h "$clean_stdin" '$h + [$n]' 2>/dev/null)
      # Fallback if jq fails
      if [ -z "$messages" ] || ! jq -e '.' <<< "$messages" >/dev/null 2>&1; then
          messages="$clean_stdin"
      fi
    else
      messages="$clean_stdin"
    fi
  elif [ -n "$prompt" ]; then
    messages=$(jq -n --arg p "$prompt" --arg c "$stdin_content" '[{role:"user", content: ($p + "\n\nCONTEXT:\n" + $c)}]')
  else
    messages=$(jq -n --arg p "" --arg c "$stdin_content" '[{role:"user", content: $c}]')
  fi
elif [ -n "$prompt" ]; then
  messages=$(jq -n --arg p "$prompt" '[{"role":"user","content":$p}]')
else
  exit 1
fi

# Apply system context if requested
if [ "$USE_SYSTEM_MSG" = true ] && [ -n "$SYSTEM_MESSAGE" ]; then
  messages=$(jq --arg sys "$SYSTEM_MESSAGE" '[{role: "system", content: $sys}] + .' <<< "$messages")
fi

# --- CORE ROUTING ENGINE ---

if [ -n "$TEE_MODE" ]; then
  # 1. Resolve the conversation state using infer
  # Note: infer outputs JSON to stdout, emojis to stderr.
  log_info "1. TEE_MODE=$TEE_MODE messages=${messages//$'\n'/\\n}"
  full_convo=$(printf "%s\n" "$messages" | infer)

  # 2. Extract the last assistant reply for the human operator
  last_reply=$(jq -r '.[-1].content // empty' <<< "$full_convo" 2>/dev/null)
  
  # 3. Print the human-readable text to stderr (with a leading newline to clear the emojis)
  printf "\n%s\n" "$last_reply" >&2
  
  # 4. CRITICAL: Print the full JSON history to stdout for the next pipe
  printf "%s\n%s\n" "${PIPELINE_MAGIC_HEADER}" "$full_convo"
elif [ -t 1 ]; then
  # Contract Rule: If at EOL terminal, hand over to answer to print pristine markdown
  log_debug "Sending to answer"
  log_info "2. TEE_MODE=$TEE_MODE messages=${messages//$'\n'/\\n}"
  printf "%s\n%s\n" "${PIPELINE_MAGIC_HEADER}" "$messages" | "${SCRIPT_DIR}/answer"
else
  # Contract Rule: Inside a pipe loop, forward the updated full JSON history state
  log_info "3. TEE_MODE=$TEE_MODE messages=${messages//$'\n'/\\n}"
  printf "%s\n%s\n" "${PIPELINE_MAGIC_HEADER}" "$messages"
fi
