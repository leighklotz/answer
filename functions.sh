# shellcheck shell=bash

# source this file to define the functions

# Require bash 4+
if [ "${BASH_VERSINFO[0]}" -lt 4 ]; then
    echo "🦶ERROR: bash 4 or later is required (running ${BASH_VERSION})." >&2
    return 1 2>/dev/null
fi

# Check if ask.sh is available
if ! command -v ask.sh &> /dev/null; then
    echo "🦶$0: WARN: ask.sh is not on the PATH.  Please add the directory containing ask.sh to your PATH environment variable." >&2
fi

# Source env.sh if variables are not already defined
if [ -z "${VIA_API_CHAT_BASE+x}" ] && [ -f "$(dirname "${BASH_SOURCE[0]}")/env.sh" ]; then
    source "$(dirname "${BASH_SOURCE[0]}")/env.sh"
fi

PIPELINE_MAGIC_HEADER="Content-Type: application/x-llm-history+json"

function _strip_header() {
  local input="$1"

  # Remove the header line if present.
  input="${input#"${PIPELINE_MAGIC_HEADER}"}"

  # Remove a single leading newline if present.
  if [[ "$input" == $'\n'* ]]; then
    input="${input#$'\n'}"
  fi

  printf '%s\n' "$input"
}

function bx ()
{
    local quiet
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -q) quiet=1; shift ;;
            -*) echo "🦶bx: unknown option $1" >&2; return 1 ;;
            *) break ;;
        esac
    done

    bx.sh "$@"
    local s=$?
    if [ $s -ne 0 ] && [ -z "${quiet}" ] ; then
        echo "🦶bx: ERROR: bx.sh failed with exit code $s" >&2
        return 1
    fi
}

function tools ()
{
    local s

    # pass through to tools.sh which will error appropriately.
    tools.sh "$@"
    s=$?

    if [ $s -ne 0 ]; then
        echo "🦶ERROR: tools.sh failed with exit code $s" >&2
        return $s
    fi
}

# if input starts with magic header, runs it through answer.
function pipetest()
{
    # Sanity Check: If running interactively but no prompt provided, warn of potential hang
    if [ -t 0 ] && [[ "$*" != *"-i"* ]]; then
        echo "🦶pipetest: No user query detected in arguments; waiting for STDIN..." >&2
    fi

    local user_query="$*"

    # Capture stdin first
    local input=$(cat)

    # If stdin is an unresolved conversation, resolve it to assistant text first.
    if [[ "$input" == "${PIPELINE_MAGIC_HEADER}"* ]]; then
      input=$(printf '%s\n' "$input" | answer)
    fi


    # Auto-detect the best available viewing tool
    local pager
    if [ -n "${PIPETEST_PAGER}" ]; then
        pager="${PIPETEST_PAGER}"
    elif command -v batcat >/dev/null 2>&1; then
        pager="batcat --style=numbers,grid"
    elif command -v bat >/dev/null 2>&1; then
        pager="bat --style=numbers,grid"
    else
        pager="cat"
    fi

    # Render file content directly to stderr
    printf "%s" "${input}" | ${pager} 1>&2

    # Safe interactive prompt from /dev/tty
    local reply
    read -r -p "🤖 ${user_query}: Y or N? " reply < /dev/tty

    printf "\n" 1>&2
    case "${reply,,}" in
        y*)
            printf "%s" "${input}"
        ;;
        *)
            printf "🚫 discarded\n" 1>&2
        ;;
    esac
}

# use `builtin help` if you want native bash help command
function help ()
{
    help.sh "$@"
}

function ask ()
{
    ask.sh "$@"
}

function _find_cache_dir () {
  local current_dir
  current_dir="$(pwd)"

  # 1. Traverse upward looking strictly for a .hallux workspace directory anchor.
  while [ "$current_dir" != "/" ]; do
    if [ -d "${current_dir}/.hallux" ]; then
      printf "%s/.hallux/cache" "$current_dir"
      return 0
    fi
    current_dir="$(dirname "$current_dir")"
  done

  # 2. Fall back to the user home baseline path if the folder anchor exists.
  if [ -d "${HOME}/.hallux" ]; then
    printf "%s/.hallux/cache" "${HOME}"
    return 0
  fi

  # 3. Ultimate system-standard fallback location.
  printf "%s/.config/hallux/cache" "${HOME}"
}

function _infer () {
  local stdin_content clean_stdin last_role
  stdin_content=$(cat)

  # Strip optional pipeline header.
  if [[ "$stdin_content" == "${PIPELINE_MAGIC_HEADER}"* ]]; then
    clean_stdin=$(_strip_header "$stdin_content")
  else
    clean_stdin="$stdin_content"
  fi

  # Contract: _infer takes a JSON array of chat messages.
  if ! jq -e 'type == "array"' <<< "$clean_stdin" >/dev/null 2>&1; then
    echo "[]"
    return 0
  fi

  # If already resolved, pass through unchanged.
  last_role=$(jq -r 'if length > 0 then .[-1].role // empty else empty end' <<< "$clean_stdin")
  if [ "$last_role" != "user" ]; then
    printf "%s\n" "$clean_stdin"
    return 0
  fi

  local api_key="${OPENAI_API_KEY:-}"
  local endpoint="${VIA_API_CHAT_BASE}/v1/chat/completions"

  local request
  request=$(jq -n \
    --argjson messages "$clean_stdin" \
    --arg model "${VIA_MODEL:-gpt-3.5-turbo}" \
    --argjson thinking "${ENABLE_THINKING:-false}" \
    --argjson max_tokens "${VIA_MAX_TOKENS:-4096}" \
    '{
      model: $model,
      messages: $messages,
      max_tokens: $max_tokens,
      thinking: $thinking
    }')

  local server_model fingerprint request_hash cache_dir cache_file response_json
  server_model=$(curl -fsS "${VIA_API_CHAT_BASE}/v1/models" |
    jq -r '.data[0].id // .id // "local_model"' 2>/dev/null || printf "local_model")

  fingerprint=$(printf "%s" "$server_model" | tr '/:' '__')
  request_hash=$(printf "%s" "$request" | openssl dgst -sha256 | awk '{print $2}')

  cache_dir=$(_find_cache_dir)
  mkdir -p "$cache_dir"
  cache_file="${cache_dir}/${fingerprint}:${request_hash}.json"

  if [ -f "$cache_file" ]; then
    printf "🎯" >&2
    response_json=$(cat "$cache_file")
  else
    printf "💭" >&2
    response_json=$(curl -fsS -X POST "$endpoint" \
      -H "Authorization: Bearer $api_key" \
      -H "Content-Type: application/json" \
      -d "$request") || return 1
  fi

  # Contract: OpenAI-compatible chat completion response with non-empty assistant content.
  local assistant_content
  assistant_content=$(
    jq -er '
      .choices[0].message.content
      | select(type == "string" and length > 0)
    ' <<< "$response_json" 2>/dev/null
  ) || {
    echo "🦶infer: ERROR: empty or missing assistant content in chat completion response" >&2
    jq -c '{id, object, choices, error}' <<< "$response_json" >&2 2>/dev/null || true
    return 1
  }

  # Only cache responses that passed validation.
  if [ ! -f "$cache_file" ]; then
    local tmp_cache
    tmp_cache="${cache_file}.$$"
    printf "%s" "$response_json" > "$tmp_cache"
    mv "$tmp_cache" "$cache_file"
  fi

  local assistant_msg
  assistant_msg=$(jq -n -c --arg c "$assistant_content" \
    '{role: "assistant", content: $c}')

  printf '%s\n' "$clean_stdin" | jq -c --argjson msg "$assistant_msg" '. + [$msg]'
}

function hx() {
    if [ "$1" == "clear_cache" ]; then
        cache_dir=$(_find_cache_dir)
        echo "rm -rf $cache_dir"
        return 0
    else
        echo "usage: hx clear_cache"
        return 1
    fi
}
