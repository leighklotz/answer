#!/usr/bin/env -S bash

SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE}")")"

source "${SCRIPT_DIR}/env.sh"
source "${SCRIPT_DIR}/logging.sh"
source "${SCRIPT_DIR}/functions.sh"

# --- ARGUMENT PARSING ---
USE_SYSTEM_MSG=false
PLAIN_INPUT=""
TEE_MODE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    -i | --input) PLAIN_INPUT="1"; shift ;;
    --use-system-message) USE_SYSTEM_MSG=true; shift ;;
    --tee | -t) TEE_MODE="1"; shift ;;
    --) break ;;
    --help) echo "Usage: ask [-i|--input] [--use-system-message] [--tee|-t] [prompt]" >&2; exit 0;;
    --*|-*) echo "unrecognized option $1"; exit 0 ;;
    *) break ;;
  esac
done

prompt="$*"

# --- INPUT HANDLING & HISTORY BUILDING ---
# If stdin is a pipe OR if we are in a TTY and -i was specified
if [[ ! -t 0 || "$PLAIN_INPUT" == "1" ]]; then
  _mktemp_reg 'ask.XXXXXX.txt' && stdin_tmp="$MKTEMP_REG"
  
  # Prompt if we are in a TTY and -i was specified
  if [[ -t 0 && "$PLAIN_INPUT" == "1" ]]; then
    printf "💬 Give input followed by Ctrl-D:\n" >&2
  fi

  # Read STDIN
  log_trace "stdin_temp=$stdin_tmp"
  cat > "$stdin_tmp"

  is_history=false
  # If we are not in "-i" mode, check if the input is a history continuation
  if [[ "$PLAIN_INPUT" != "1" ]]; then
      first_line=""
      IFS= read -r first_line < "$stdin_tmp" || true
      if [[ "$first_line" == "${PIPELINE_MAGIC_HEADER}" ]]; then
          is_history=true
      else
          # If it's not history and not -i, we treat the piped input as the content
          # but we don't set PLAIN_INPUT="1" because we want to preserve the prompt merge logic below
          : 
      fi
  fi

  if [[ "$PLAIN_INPUT" == "1" ]]; then
      # MODE: Plain Input (via -i or manual stdin)
      messages=$(jq -n \
                    --arg p "$prompt" \
                    --rawfile c "$stdin_tmp" \
                    '[{role: "user", content: ($p + "\n\nATTACHMENT:\n" + $c)}]')
  elif [[ "$is_history" == true ]]; then
    # MODE: Conversation History (JSON)
    _mktemp_reg "ask.XXXXXX.json" && clean_stdin_tmp="$MKTEMP_REG"

    tail -n +2 "$stdin_tmp" > "$clean_stdin_tmp"

    log_info "0. TEE_MODE=$TEE_MODE resolving incoming history"
    if ! clean_stdin=$(_infer < "$clean_stdin_tmp"); then
      log_and_exit 1 "Inference failed while resolving prior conversation state."
    fi

    if ! jq -e '.' <<< "$clean_stdin" >/dev/null 2>&1; then
      echo "🦶ask: WARN: infer returned invalid JSON, resetting state." >&2
      clean_stdin="[]"
    fi

    if [[ -n "$prompt" ]]; then
      new_msg=$(jq -n --arg p "$prompt" '{"role":"user","content":$p}')
      messages=$(jq -n -c --argjson n "$new_msg" --argjson h "$clean_stdin" '$h + [$n]' 2>/dev/null)
      if [[ -z "$messages" ]] || ! jq -e '.' <<< "$messages" >/dev/null 2>&1; then
        log_and_exit 1 "Failed to merge new prompt into conversation history."
      fi
    else
      messages="$clean_stdin"
    fi
  elif [[ -n "$prompt" ]]; then
    # MODE: Prompt + Piped Content
    messages=$(jq -n --arg p "$prompt" --rawfile c "$stdin_tmp" '[{role:"user", content: ($p + "\n\nCONTEXT:\n" + $c)}]')
  else
    # MODE: Only Piped Content
    messages=$(jq -n --rawfile c "$stdin_tmp" '[{role:"user", content: $c}]')
  fi
elif [[ -n "$prompt" ]]; then
  # MODE: Interactive Command Line Argument (No stdin, no -i)
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

# If TEE_MODE, call _infer and print the last assistant reply to stderr, then print
# the  header+full_convo to stdout.
# Not in TEE_MODE and at terminal, literally pipe the header+full_convo to answer.
# Not in TEE_MODE mode and in a pipe, header+full_convo.

if [ -n "$TEE_MODE" ]; then
  # Resolve the conversation state (idempotent)
  full_convo=$(printf "%s\n" "$messages" | _infer)

  # Extract the last assistant reply
  assistant_reply=$(jq -r '.[-1].content // empty' <<< "$full_convo" 2>/dev/null)
  
  # Print human-readable text to stderr
  printf '\n%s\n' "$assistant_reply" >&2
  
  # Forward full JSON history to stdout
  printf "%s\n%s\n" "${PIPELINE_MAGIC_HEADER}" "$full_convo"
elif [ -t 1 ]; then
  # Contract Rule: If at EOL terminal, hand over to answer to print pristine markdown
  log_debug "Sending to answer"
  printf "%s\n%s\n" "${PIPELINE_MAGIC_HEADER}" "$messages" | "${SCRIPT_DIR}/answer"
else
  # Contract Rule: Inside a pipe, forward the updated full JSON history state
  printf "💬" >&2
  printf "%s\n%s\n" "${PIPELINE_MAGIC_HEADER}" "$messages"
fi
