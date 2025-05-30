#!/bin/bash

. ~/wip/llamafiles/scripts/env.sh

# usage: ask your question | answer
# usage: bashfence cat foo.sh | ask -i your question about foo.sh | answer
# usage: ask -i your question about foo.sh < (bashfence cat foo.sh) | answer
# usage: bashfence cat foo.sh | ask -i your question about foo.sh | ask -i further comments | answer
# usage: bashfence cat foo.sh | ask -i your question about foo.sh | answer | ask -i further comments | answer

# todo: write usage
function usage {
  echo "Usage: ask [options] [prompt]"
  echo ""
  echo "  ask -i <prompt>                Ask a question directly."
  echo "  bashfence cat <file> | ask -i <question>  Ask a question about the output of a bash command."
  echo "  <bash command> | ask -i <question>  Same as above, piping the command's output."
  echo "  ask -i <question> < (bash command)  Alternative way to pipe the command's output."
  echo "  -i, --input <prompt>           Specify the prompt to ask."
  echo "  --help                          Display this help message."
  echo ""
  echo "Example:"
  echo "  ask -i 'What is the capital of France?'"
  echo "  bashfence cat my_script.sh | ask -i 'What does this script do?'"
}


PLAIN_INPUT=""
if [ "$1" = "-i" ] || [ "$1" = "--input" ]; then
    shift
    PLAIN_INPUT="1"
elif [ "$1" = "--help" ]; then
    usage
    exit 0
fi

# Read the existing chat history from stdin or create a new one
if [ -t 0 ]; then
    # No stdin, read prompt from arguments
    prompt="$*"
    messages=$(jq -n --arg prompt "$prompt" '[{"role":"user","content":$prompt}]')
else
    # Read chat history from stdin
    read -r -d '' input || true
    prompt="$*"
    if [ -n "${PLAIN_INPUT}" ]; then
        printf -v prompt "%s\n\n%s" "${prompt}" "${input}"
        messages=$(jq -n  --arg prompt "$prompt" '[{"role":"user","content":$prompt}]')
    else
        new_message=$(jq -n --arg prompt "$prompt" '{"role":"user","content":$prompt}')
        messages=$(jq --argjson new_message "$new_message" '. + [$new_message]' <<< "$input")
    fi
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
      cache_prompt: true}')")"

# Extract and append the reply
assistant_reply="$(jq -r '.choices[0].message.content // empty' <<< "$response")"

if [ -z "$assistant_reply" ]; then
  echo "No response received from the API." >&2
  exit 1
else
  new_assistant_message=$(jq -n --arg content "$assistant_reply" '{"role":"assistant","content":$content}')
  messages=$(jq --argjson reply "$new_assistant_message" '. + [$reply]' <<< "$messages")
  echo "$messages"
fi
