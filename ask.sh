#!/usr/bin/env -S bash
SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE}")")"
source "${SCRIPT_DIR}/env.sh"
source "${SCRIPT_DIR}/logging.sh"
source "${SCRIPT_DIR}/functions.sh"

: "${PIPELINE_MAGIC_HEADER:="Content-Type: application/x-llm-history+json"}"

function usage {
  echo "Usage: ask [options] [prompt]"
  echo ""
  echo "  -i, --input <prompt>        Specify the prompt to ask."
  echo "  --use-system-message        Prepend SYSTEM_MESSAGE env var to the conversation."
  echo "  bx cat <file> | ask -i <question> Ask a question about the output of a bash command."
  echo "  <bash command> | ask -i <question> Same as above, piping the command's output."
  echo "  ask -i <question> < (bash command) Alternative way to pipe the command's output."
  echo "  --help                      Display this help message."
  echo ""
  echo "Example:"
  echo "  ask -i 'What is the capital of France?'"
  echo "  bx cat my_script.sh | ask -i 'What does this script do?'"
}

# --- ARGUMENT PARSING ---
USE_SYSTEM_MSG=false
PLAIN_INPUT=""
: "${TEMPERATURE:=}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    -i|--input)
      PLAIN_INPUT="1"
      shift
      ;;
    --use-system-message)
      USE_SYSTEM_MSG=true
      shift
      ;;
    --help)
      usage
      exit 0
      ;;
    *)
      break
      ;;
  esac
done

prompt="$*"

# --- INPUT HANDLING ---
input=""
if [ ! -t 0 ]; then
  # Capture everything from stdin first
  stdin_content=$(cat)
  
  # Check if it's a JSON conversation (Magic Header or raw array starting with '[')
  first_char=$(echo "$stdin_content" | head -c 1 | tr -d '[:space:]')
  is_json=false
  if [ "$first_char" = "[" ] || echo "$stdin_content" | grep -q "^${PIPELINE_MAGIC_HEADER}" ; then
    is_json=true
  fi

  if [ "$PLAIN_INPUT" = "1" ]; then
    # MODE: Text Attachment (-i)
    messages=$(jq -n --arg p "$prompt" --arg c "$stdin_content" '[{role:"user", content: ($p + "\n\nATTACHMENT:\n" + $c)}]')
  elif [ "$is_json" = true ]; then
    # MODE: Conversation History (JSON)
    # Safe vertical bar delimiters to clear Content-Type paths without crashing sed
    clean_stdin=$(echo "$stdin_content" | sed "1s|^${PIPELINE_MAGIC_HEADER}||")
    
    # PIPELINE FIX: Check if incoming stream is a raw server response payload (contains .choices)
    if jq -e '.choices' <<< "$clean_stdin" >/dev/null 2>&1; then
        # Extract the message into a standard, clean-printed JSON format array string
        # This strips the volatile server transaction id/created timestamps and matches internal memory strings exactly
        clean_stdin=$(jq -c '[.choices[0].message]' <<< "$clean_stdin" 2>/dev/null || echo "$clean_stdin")
    else
        # Ensure even standard raw conversation inputs are evaluated via a matching string compilation channel
        clean_stdin=$(jq -c '.' <<< "$clean_stdin" 2>/dev/null || echo "$clean_stdin")
    fi


    # Handle the transition if the history structure needs an intermediate inference generation step
    last_role=$(jq -r 'if type == "array" and length > 0 then .[-1].role else empty end' <<< "$clean_stdin" 2>/dev/null)
    if [ "$last_role" = "user" ]; then
       # Intercept pipeline: Pass directly to answer first to generate text context before chaining
       raw_response=$(printf "%s\n%s\n" "${PIPELINE_MAGIC_HEADER}" "$clean_stdin" | "${SCRIPT_DIR}/answer")
       
       # Extract the raw response JSON (cleaning any trailing pipeline headers)
       clean_response=$(echo "$raw_response" | sed "1s|^${PIPELINE_MAGIC_HEADER}||")
       
       # FIX: Extract the raw message array out of the server payload structure natively.
       # This matches the identical structural array output of your manual answer injection step.
       clean_stdin=$(jq -c '.choices[0].message as $msg | ($msg | [ . ])' <<< "$clean_response" 2>/dev/null || echo "$clean_stdin")
    fi

    if [ -n "$prompt" ]; then
      new_message=$(jq -n --arg prompt "$prompt" '{"role":"user","content":$prompt}')
      # FIXED: Pass history via direct inline string token variable instead of file descriptors
      messages=$(jq -n --argjson new_msg "$new_message" --argjson history "$clean_stdin" '
        if ($history | type == "array") then $history + [$new_msg] else [$history, $new_msg] end
      ')
    else
      messages="$clean_stdin"
    fi
  elif [ -n "$prompt" ]; then
    # MODE: Plain text pipe
    messages=$(jq -n --arg p "$prompt" --arg c "$stdin_content" '[{role:"user", content: ($p + "\n\nCONTEXT:\n" + $c)}]')
  else
    # Raw context fallback
    messages=$(jq -n --arg p "" --arg c "$stdin_content" '[{role:"user", content: $c}]')
  fi
elif [ ! -z "$prompt" ]; then
  messages=$(jq -n --arg prompt "$prompt" '[{"role":"user","content":$prompt}]')
else
  exit 1
fi

# Ensure messages is a valid array even if empty or malformed above
if [[ ! "$messages" =~ ^\[ ]]; then
  echo "ask: error parsing input into JSON conversation." >&2
  exit 1
fi

# --- SYSTEM MESSAGE INJECTION ---
if [ "$USE_SYSTEM_MSG" = true ] && [ -n "$SYSTEM_MESSAGE" ]; then
  messages=$(jq --arg sys "$SYSTEM_MESSAGE" '[{role: "system", content: $sys}] + .' <<< "$messages")
fi

# --- OUTPUT AND EXECUTION ---
if [ -t 1 ]; then
  # Pass JSON history straight to answer natively
  printf "%s\n%s\n" "${PIPELINE_MAGIC_HEADER}" "$messages" | "${SCRIPT_DIR}/answer"
else
  # Inside a pipe sequence: pass the raw data block forward cleanly
  printf "%s\n%s\n" "${PIPELINE_MAGIC_HEADER}" "$messages"
fi
