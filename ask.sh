#!/usr/bin/env -S bash

SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE}")")"

source ~/wip/llamafiles/scripts/env.sh

source "${SCRIPT_DIR}/functions.sh"

### Key Changes Explained:
# 1.  **Robust Argument Parsing**: I replaced the `if/elif` with a `while/case` loop. This is necessary because `--use-system-message` can appear before or after `-i`. The `break` in the `*)` case ensures that once we hit the actual question (the prompt), we stop trying to parse flags and treat the rest as the string.
# 2.  **System Message Injection**: I added a block after the `messages` array is fully constructed but before the `curl` command. 
#     *   `jq --arg sys "$SYSTEM_MESSAGE" '[{role: "system", content: $sys}] + .' <<< "$messages"`
#     *   This `jq` command takes the existing array (`.`) and prepends a new array containing the system message object.
# 3.  **Environment Variable Safety**: The injection only triggers if `USE_SYSTEM_MSG` is true **and** `$SYSTEM_MESSAGE` is not empty, preventing the injection of empty system roles which can cause API errors.


# usage: ask your question | answer
# usage: ask your question
# usage: bx cat foo.sh | ask -i your question about foo.sh | answer
# usage: bx cat foo.sh | ask -i your question about foo.sh 
# usage: ask -i your question about foo.sh < (bx cat foo.sh) | answer
# usage: ask -i your question about foo.sh < (bx cat foo.sh) 
# usage: bx cat foo.sh | ask -i your question about foo.sh | ask -i further comments | answer
# usage: bx cat foo.sh | ask -i your question about foo.sh | ask -i further comments 
# usage: bx cat foo.sh | ask -i your question about foo.sh | answer | ask -i further comments | answer
# usage: bx cat foo.sh | ask -i your question about foo.sh | answer | ask -i further comments 
# usage: ask.sh write 'fib in python. output a single impl in a code fence with a call to fib(20)'  
# usage: ask.sh write 'fib in python. output a single impl in a code fence with a call to fib(20)'  | answer 
# usage: ask.sh write 'fib in python. output a single impl in a code fence with a call to fib(20)'  | answer | unfence 
# usage: ask.sh write 'fib in python. output a single impl in a code fence with a call to fib(20)'  | answer | unfence | python

function usage {
  echo "Usage: ask [options] [prompt]"
  echo ""
  echo "  -i, --input <prompt>           Specify the prompt to ask."
  echo "  --use-system-message           Prepend SYSTEM_MESSAGE env var to the conversation."
  echo "  bx cat <file> | ask -i <question>  Ask a question about the output of a bash command."
  echo "  <bash command> | ask -i <question>  Same as above, piping the command's output."
  echo "  ask -i <question> < (bash command)  Alternative way to pipe the command's output."
  echo "  --help                          Display this help message."
  echo ""
  echo "Example:"
  echo "  ask -i 'What is the capital of France?'"
  echo "  bx cat my_script.sh | ask -i 'What does this script do?'"
}

# --- ARGUMENT PARSING ---
USE_SYSTEM_MSG=false
PLAIN_INPUT=""

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
            # Stop parsing flags when we hit the first non-option argument
            break
            ;;
    esac
done

prompt="$*"

# --- INPUT HANDLING ---
input=""
if [ ! -t 0 ]; then
    # Capture everything from stdin first to avoid multiple reads issues
    stdin_content=$(cat)
    
    if [[ "$prompt" == *"$'\n'"* ]] || [ -n "$prompt" ] && command -v jq >/dev/null; then
        # Check if it's a JSON conversation (Magic Header or raw array starting with '[')
        first_char=$(echo "$stdin_content" | head -c 1 | tr -d '[:space:]')
        is_json=false
        if [ "$first_char" = "[" ] || echo "$stdin_content" | grep -q "PIPELINE_MAGIC_HEADER"; then
            is_json=true
        fi

        if [ "$is_attachment" = true ]; then
             # MODE: Text Attachment (-i)
             # We take the prompt (args) and treat stdin as a single block of text to be asked about.
             messages=$(jq -n --arg p "$prompt" --arg c "$stdin_content" '[{role:"user", content: ($p + "\n\nATTACHMENT:\n" + $c)}]')
        elif [ "$is_json" = true ]; then
             # MODE: Conversation History (JSON)
             # Strip header if present, then append the new prompt to history.
             clean_stdin=$(echo "$stdin_content" | sed "1s/${PIPELINE_MAGIC_HEADER}//")
             new_message=$(jq -n --arg prompt "$prompt" '{"role":"user","content":$prompt}')
             messages=$(jq --argjson new_msg "$new_message" --argjson history <(echo "$clean_stdin") '$history + [$new_msg]')
        else
            # MODE: Plain text pipe (e.g., cat file | ask prompt) 
            # We treat the piped content as context for the prompt
            messages=$(jq -n --arg p "$prompt" --arg c "$stdin_content" '[{role:"user", content: ($p + "\n\nCONTEXT:\n" + $c)}]')
        fi
    else
        input="$stdin_content" # Fallback logic
    fi
elif [ ! -z "$prompt" ]; then
    # No stdin, but prompt exists (e.g., ask "hello")
    messages=$(jq -n --arg prompt "$prompt" '[{"role":"user","content":$prompt}]')
else
     exit 1 # Nothing to do
fi

# Ensure messages is a valid array even if empty or malformed above
if [[ ! "$messages" =~ ^\[ ]]; then
    echo "ask: error parsing input into JSON conversation." >&2
    exit 1
fi

# --- SYSTEM MESSAGE INJECTION ---
if [ "$USE_SYSTEM_MSG" = true ] && [ -n "$SYSTEM_MESSAGE" ]; then
    # Prepend the system message to the start of the messages array
    messages=$(jq --arg sys "$SYSTEM_MESSAGE" '[{role: "system", content: $sys}] + .' <<< "$messages")
fi

# API setup
api_key="${OPENAI_API_KEY:-}"
VIA_API_CHAT_COMPLETIONS_ENDPOINT="${VIA_API_CHAT_BASE}/v1/chat/completions"

# Perform API call
response="$(curl -s -X POST "${VIA_API_CHAT_COMPLETIONS_ENDPOINT}" \
    -H "Authorization: Bearer $api_key" \
    -H "Content-Type: application/json" \
    -d "$(jq -n --argjson messages "$messages" \
    --arg model "gpt-3.5-turbo" \
    --argjson temperature 0.7 \
    --argjson max_tokens 4096 \
    '{model: $model,
      mode: "instruct",
      temperature: $temperature,
      max_tokens: $max_tokens,
      messages: $messages,
      top_k: 20,
      top_p: 0.95,
      min_p: 0.1,
      tfs_z: 1,
      typical_p: 1.0,
      repeat_penalty: 1.0,
      repeat_last_n: 1024,
      presence_penalty: 0.0,
      frequency_penalty: 0.0,
      dry_multiplier: 0,
      dry_base: 1.75,
      dry_allowed_length: 2,
      dry_penalty_last_n: 1024,
      xtc_probability: 0,
      xtc_threshold: 0.1,
      seed: -1,
      ignore_eos: false,
      n_predict: 10482,
      enable_thinking: true,
      cache_prompt: true}')")"

# Extract and append the reply
assistant_reply="$(jq -r '.choices[0].message.content // empty' <<< "$response")"

if [ -z "$assistant_reply" ]; then
  echo "No response received from the API." >&2
  exit 1
else
  new_assistant_message=$(jq -n --arg content "$assistant_reply" '{"role":"assistant","content":$content}')
  messages=$(jq --argjson reply "$new_assistant_message" '. + [$reply]' <<< "$messages")
  
  if [ -t 1 ]; then
      # If it's a terminal, we want the user to see the text, 
      # so pipe the JSON to 'answer' 
      printf "%s\n%s\n" "${PIPELINE_MAGIC_HEADER}" "$messages" | answer
  else
      # If it's a pipe, output the header + JSON so 'tools' or 'answer' can parse it.
      printf "%s\n%s\n" "${PIPELINE_MAGIC_HEADER}" "$messages"
  fi
fi
