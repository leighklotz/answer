#!/usr/bin/env -S bash
SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE}")")"
source "${SCRIPT_DIR}/env.sh"
source "${SCRIPT_DIR}/logging.sh"
source "${SCRIPT_DIR}/functions.sh"

# Resolve directory hierarchy dynamically, defaulting if missing
CACHE_DIR=$(find_cache_dir)
mkdir -p "${CACHE_DIR}"

TEE_MODE=""
NO_DECORATE=""
PIPELINE_MAGIC_HEADER="Content-Type: application/x-llm-history+json"

# arg parsing loop
while [[ $# -gt 0 ]]; do
  case "$1" in
    --tee|-t)
      TEE_MODE="1"
      shift
      ;;
    *)
      echo "Usage: $0 [--tee | -t]" >&2
      echo "$0: unknown argument $1" >&2
      exit 1
      ;;
  esac
done

# Read stdin and extract JSON context or raw input
if [ ! -t 0 ]; then
  raw_input=$(cat)
  if [[ "$raw_input" == "${PIPELINE_MAGIC_HEADER}"* ]]; then
    # We received a Conversation State (Header + JSON body)
    messages="${raw_input#${PIPELINE_MAGIC_HEADER}}"
    messages="${messages#$'\n'}"
  else
    # We received raw text or un-headered JSON
    messages="$raw_input"
  fi
else
  # No stdin (direct call)
  messages="[]"
fi

# API setup
api_key="${OPENAI_API_KEY:-}"
VIA_API_CHAT_COMPLETIONS_ENDPOINT="${VIA_API_CHAT_BASE}/v1/chat/completions"

# Create API body
request="$(jq -n --argjson messages "$messages" \
  --arg model "gpt-3.5-turbo" \
  --argjson max_tokens 4096 \
  '{model: $model, thinking: true, mode: "instruct", max_tokens: $max_tokens, messages: $messages, top_k: 20, top_p: 0.95, min_p: 0.1, tfs_z: 1, typical_p: 1.0, repeat_penalty: 1.0, repeat_last_n: 1024, presence_penalty: 0.0, frequency_penalty: 0.0, dry_multiplier: 0, dry_base: 1.75, dry_allowed_length: 2, dry_penalty_last_n: 1024, xtc_probability: 0, xtc_threshold: 0.1, seed: -1, ignore_eos: false, n_predict: 10482, enable_thinking: true, cache_prompt: true}')"

# ==================== CACHING SYSTEM ====================

# 1. Fetch active model metadata from the server instantly (0ms inference cost)
# This captures any changed weight files, load parameters, or engine switches.
SERVER_MODEL=$(curl -s "${VIA_API_CHAT_BASE}/v1/models" | jq -r '.data[0].id // .data.id // "local_model"')


# 2. Sanitize the model name into a safe fingerprint string for a file name
FINGERPRINT=$(printf "%s" "$SERVER_MODEL" | tr '/' '_')

# 3. Calculate a byte-accurate hash of the raw client request
REQUEST_HASH=$(printf "%s" "$request" | openssl dgst -sha256 | awk '{print $2}')

# 4. Search your cache safely using the verified server model string
CACHE_MATCH=$(find "$CACHE_DIR" -name "${FINGERPRINT}:${REQUEST_HASH}:*" -print -quit)

if [ -n "$CACHE_MATCH" ]; then
  # Cache Hit: Print the target anchor horizontally to stderr with NO trailing newline
  printf "🎯" >&2
  response="$(cat "$CACHE_MATCH")"
else
  # Cache Miss: Print the thought bubble horizontally to stderr with NO trailing newline
  printf "💭" >&2
  response="$(curl -s -X POST "${VIA_API_CHAT_COMPLETIONS_ENDPOINT}" \
    -H "Authorization: Bearer $api_key" \
    -H "Content-Type: application/json" \
    -d "$request")"
    
  # Extract the true transaction ID from the server response
  RESPONSE_ID=$(printf "%s" "$response" | jq -r '.id // "unknown_id"')
  
  # Construct the full URN file name and save it to disk
  FULL_CACHE_FILE="${CACHE_DIR}/${FINGERPRINT}:${REQUEST_HASH}:${RESPONSE_ID}.json"
  printf "%s" "$response" > "$FULL_CACHE_FILE"
fi

# ========================================================

# Extract the reply text to verify the server didn't send an empty payload
assistant_reply="$(jq -r '.choices[0].message.content // empty' <<< "$response")"
s=$?
if [ $s -ne 0 ]; then
  echo "Footanswer ERROR: answer.sh failed with exit code $s" >&2
  exit 1
fi

if [ -z "$assistant_reply" ]; then
  log_and_exit 1 "Cannot parse API response: ${response}"
fi

# --- INTENT-BASED OUTPUT ROUTING ---

# Check if stdout is an active pipeline node or if TEE mode is explicitly requested
if [ ! -t 1 ] || [ -n "$TEE_MODE" ]; then
  
  # If TEE mode is active, mirror the human-readable text out to stderr
  if [ -n "$TEE_MODE" ]; then
    printf "%s\n" "$assistant_reply" >&2
  fi
  
  # Forward the structured JSON object payload down stdout for the next pipe step
  printf "%s\n%s\n" "${PIPELINE_MAGIC_HEADER}" "$response"

else
  # Ultimate destination is a terminal screen:
  # 1. Print a single newline to stderr to break the line right after the horizontal emojis finish
  printf "\n" >&2
  
  # 2. Print ONLY the text response content to stdout
  printf "%s\n" "$assistant_reply"
fi
