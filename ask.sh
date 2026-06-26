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
    # Auto-resolve the previous turn if it was an unresolved user query
    # Pass the stdin string block straight into infer natively via a heredoc/herestring
    clean_stdin=$(infer <<< "$stdin_content")
    if [ -n "$prompt" ]; then
      new_msg=$(jq -n --arg p "$prompt" '{"role":"user","content":$p}')
      messages=$(jq -c --argjson n "$new_msg" --argjson h "$clean_stdin" '$h + [$n]')
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
  # Contract Rule: ask -t resolves the state, logs output to stderr, and passes full JSON down stdout
  full_convo=$(printf "%s\n" "$messages" | infer)
  last_reply=$(jq -r '.[-1].content // empty' <<< "$full_convo")
  
  printf "\n%s\n" "$last_reply" >&2
  printf "%s\n%s\n" "${PIPELINE_MAGIC_HEADER}" "$full_convo"

elif [ -t 1 ]; then
  # Contract Rule: If at EOL terminal, hand over to answer to print pristine markdown
  printf "%s\n%s\n" "${PIPELINE_MAGIC_HEADER}" "$messages" | "${SCRIPT_DIR}/answer"
else
  # Contract Rule: Inside a pipe loop, forward the updated full JSON history state
  printf "%s\n%s\n" "${PIPELINE_MAGIC_HEADER}" "$messages"
fi
