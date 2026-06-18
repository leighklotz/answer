#!/usr/bin/env -S bash

SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE}")")"

source ~/wip/answer/env.sh
source "${SCRIPT_DIR}/functions.sh"
source "${SCRIPT_DIR}/logging.sh"

function usage {
  echo "Usage: ask [options] [prompt]"
  echo ""
  echo "  -i, --input <prompt>           Specify plain input in stdin as an attachment."
  echo "  --use-system-message           Prepend SYSTEM_MESSAGE env var to the conversation."
  echo "  --thinking true|false          Specify model reasoning."
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
: "${USE_SYSTEM_MSG:=false}"
: "${THINKING:=true}"
: "${N_PREDICT:=10482}"
: "${TEMPERATURE:=1.0}"

PLAIN_INPUT=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        -i|--input) PLAIN_INPUT="1"; shift ;;
        --thinking) THINKING="$2"; shift; shift ;;
        --use-system-message) USE_SYSTEM_MSG=true; shift ;;
        --help) usage; exit 0 ;;
        *) break ;;
    esac
done

prompt="$*"

# --- INPUT HANDLING ---
input=""
messages=""

if [ -t 0 ]; then
    # INTERACTIVE MODE
    if [ ! -z "${PLAIN_INPUT}" ]; then
        echo "Give input followed by Ctrl-D:" >&2
        input=$(cat) # Standard cat works fine in interactive TTY for Ctrl-D
        [ -n "$prompt" ] && printf -v prompt "%s\n\n%s" "${prompt}" "${input}"
    fi

    if [ -z "$prompt" ]; then
         echo "Error: No prompt provided." >&2; exit 1
    fi
    messages=$(jq -n --arg prompt "$prompt" '[{"role":"user","content":$prompt}]')

else
    # PIPED MODE (stdin is either JSON or raw text)
    echo "Input is being piped in. PLAIN_INPUT=$PLAIN_INPUT" >&2
    
    # Read the first line to check for Magic Header OR just use it as content
    IFS= read -r first_line || true

    if [[ "$first_line" == "${PIPELINE_MAGIC_HEADER}" ]]; then
        # CASE 1: It's an existing JSON conversation array
        echo "stdin is a JSON conversation array with magic header" >&2
        input=$(cat) # Read the rest of the JSON string
        messages=$(jq --arg prompt "$prompt" '. + [{"role":"user","content":$prompt}]' <<< "$input")
    else
        # CASE 2 & 3: It is raw text (either via -i or just standard piping)
        echo "stdin is a raw attachment/text stream" >&2
        
        # Capture the rest of the pipe. If no more lines, 'cat' returns immediately.
        remainder=$(cat)
        if [ ! -z "$remainder" ]; then
            input="${first_line}"$'\n'"${remainder}"
        else
            input="${first_line}"
        fi

        # We wrap the captured text and the user prompt into a single array of two messages
        messages=$(jq -n --arg attach "$input" --arg prompt "$prompt" \
            '[{"role":"user","content":$attach}, {"role":"user","content":($prompt | if . == "" then null else "\n\n\(.)" end) }]')
    fi
fi

# --- SYSTEM MESSAGE INJECTION ---
if [ "$USE_SYSTEM_MSG" = true ] && [ -n "$SYSTEM_MESSAGE" ]; then
    messages=$(jq --arg sys "$SYSTEM_MESSAGE" '[{role: "system", content: $sys}] + .' <<< "$messages")
fi

# API setup (Rest of your script remains the same)
api_key="${OPENAI_API_KEY:-}"
VIA_API_CHAT_COMPLETIONS_ENDPOINT="${VIA_API_CHAT_BASE}/v1/chat/completions"

request_data="$(jq -n --argjson messages "$messages" \
    --arg model "gpt-3.5-turbo" \
    --arg thinking "$THINKING" \
    --argjson temperature "$TEMPERATURE" \
    --argjson n_predict "$N_PREDICT" \
    --argjson max_tokens 4096 \
    '{model: $model,
      thinking: ($thinking == "true"),
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
      n_predict: $n_predict,
      cache_prompt: true}')"

log_verbose "request: ${request_data}"

response="$(curl -s -X POST "${VIA_API_CHAT_COMPLETIONS_ENDPOINT}" \
    -H "Authorization: Bearer $api_key" \
    -H "Content-Type: application/json" \
    -d "${request_data}")"

assistant_reply="$(jq -r '.choices[0].message.content // empty' <<< "$response")"

if [ -z "$assistant_reply" ]; then
  echo "No response received from the API." >&2
  exit 1
else
  new_assistant_message=$(jq -n --arg content "$assistant_reply" '{"role":"assistant","content":$content}')
  messages=$(jq --argjson reply "$new_assistant_message" '. + [$reply]' <<< "$messages")
  
  if [ -t 1 ]; then
      printf "%s" "$messages" | answer
  else
      printf "%s\n%s" "${PIPELINE_MAGIC_HEADER}" "$messages"
  fi
fi
