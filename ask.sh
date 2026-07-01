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
    --help) echo "Usage: ask [-i|--input] [--use-system-message] [--tee|-t] [prompt]" >&2; exit 0 ;;
    *) break ;;
  esac
done

prompt="$*"

# --- INPUT HANDLING & HISTORY BUILDING ---
if [ ! -t 0 ]; then
  stdin_tmp=$(mktemp)
  clean_stdin_tmp=""

  cleanup() {
    rm -f "$stdin_tmp"
    if [ -n "$clean_stdin_tmp" ]; then
      rm -f "$clean_stdin_tmp"
    fi
  }
  trap cleanup EXIT

  cat > "$stdin_tmp"

  is_history=false
  first_line=""
  IFS= read -r first_line < "$stdin_tmp" || true
  if [ "$first_line" = "${PIPELINE_MAGIC_HEADER}" ]; then
    is_history=true
  else
    PLAIN_INPUT="1"
  fi

  if [ "$PLAIN_INPUT" = "1" ]; then
      # TODO: this fails if $prompt is large; cannot pass arbitrarily-long cli args to jq
      # GOOD: This works with large stdin
      messages=$(jq -n \
                    --arg p "$prompt" \
                    --rawfile c "$stdin_tmp" \
                    '[{role: "user", content: ($p + "\n\nATTACHMENT:\n" + $c)}]')
  elif [ "$is_history" = true ]; then
    # MODE: Conversation History (JSON)
    # 1. Remove the MIME header without passing the whole payload as argv.
    clean_stdin_tmp=$(mktemp)
    tail -n +2 "$stdin_tmp" > "$clean_stdin_tmp"

    # 2. Resolve the previous turn cleanly.
    # Capture stderr separately to ensure clean_stdin is pure JSON.
    log_info "0. TEE_MODE=$TEE_MODE resolving incoming history"
    if ! clean_stdin=$(_infer < "$clean_stdin_tmp" 2>/dev/null); then
      log_and_exit 1 "Inference failed while resolving prior conversation state."
    fi

    # Validate JSON output from infer.
    if ! jq -e '.' <<< "$clean_stdin" >/dev/null 2>&1; then
      echo "🦶ask: WARN: infer returned invalid JSON, resetting state." >&2
      clean_stdin="[]"
    fi

    # 3. Append the new user prompt directly to the clean conversation history array.
    if [ -n "$prompt" ]; then
      # TODO: this fails if $prompt is large; cannot pass arbitrarily-long cli args to jq
      new_msg=$(jq -n --arg p "$prompt" '{"role":"user","content":$p}')
      # TODO: this fails if $prompt is large; cannot pass arbitrarily-long cli args to jq
      messages=$(jq -n -c --argjson n "$new_msg" --argjson h "$clean_stdin" '$h + [$n]' 2>/dev/null)
      if [ -z "$messages" ] || ! jq -e '.' <<< "$messages" >/dev/null 2>&1; then
        log_and_exit 1 "Failed to merge new prompt into conversation history."
      fi
    else
      messages="$clean_stdin"
    fi
  elif [ -n "$prompt" ]; then
    messages=$(
        # TODO: this fails if $prompt is large; cannot pass arbitrarily-long cli args to jq
        # GOOD: This works with large stdin
      jq -n \
        --arg p "$prompt" \
        --rawfile c "$stdin_tmp" \
        '[{role:"user", content: ($p + "\n\nCONTEXT:\n" + $c)}]'
    )
  else
    # GOOD: this works with long content
    messages=$(jq -n --rawfile c "$stdin_tmp" '[{role:"user", content: $c}]')
  fi
elif [ -n "$prompt" ]; then
  # TODO: this fails if $prompt is large; cannot pass arbitrarily-long cli args to jq
  messages=$(jq -n --arg p "$prompt" '[{"role":"user","content":$p}]')
else
  exit 1
fi

# Apply system context if requested
if [ "$USE_SYSTEM_MSG" = true ] && [ -n "$SYSTEM_MESSAGE" ]; then
    # this fails if $SYSTEM_MESSAGE is large, but that is ok
    # TODO: assure that stdin is a JSON array
    # TODO: verify this works
  messages=$(jq --arg sys "$SYSTEM_MESSAGE" '[{role: "system", content: $sys}] + .' <<< "$messages")
fi

# --- CORE ROUTING ENGINE ---

if [ -n "$TEE_MODE" ]; then
  # 1. Resolve the conversation state (idempotent)
  full_convo=$(printf "%s\n" "$messages" | _infer)

  # 2. Extract the last assistant reply
  last_reply=$(jq -r '.[-1].content // empty' <<< "$full_convo" 2>/dev/null)
  
  # 3. Print human-readable text to stderr
  printf '\n%s\n' "$last_reply" >&2
  
  # 4. Forward full JSON history to stdout
  printf "%s\n%s\n" "${PIPELINE_MAGIC_HEADER}" "$full_convo"
elif [ -t 1 ]; then
  # Contract Rule: If at EOL terminal, hand over to answer to print pristine markdown
  log_debug "Sending to answer"
  printf "%s\n%s\n" "${PIPELINE_MAGIC_HEADER}" "$messages" | "${SCRIPT_DIR}/answer"
else
  # Contract Rule: Inside a pipe loop, forward the updated full JSON history state
  log_info "3. TEE_MODE=$TEE_MODE forwarding messages"
  printf "%s\n%s\n" "${PIPELINE_MAGIC_HEADER}" "$messages"
fi
