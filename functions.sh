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

# Single global list for file cleanup
CLEANUP_FILES=()

function _register_file_deletion() {
  CLEANUP_FILES+=("$@")
}

function mktemp_reg() {
  local tmp
  if ! tmp=$(mktemp "$@"); then
    log_and_exit 1 "failed to create temp file"
  fi
  _register_file_deletion "$tmp"
  echo "$tmp"
}

function _delete_registered_files() {
  local file
  for file in "${CLEANUP_FILES[@]}"; do
      if [ -d "$file" ] && [ ! -L "$file" ]; then
          rmdir -- "$file" || log_warn "Unable to delete directory $file"
      elif [ -f "$file" ] || [ -L "$file" ]; then
          rm -f -- "$file"
      fi
  done
  CLEANUP_FILES=()
}

trap _delete_registered_files EXIT INT TERM HUP


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

# 2. if input starts with magic header, get answer
# 2. prompt answer and ask for confirmation
# 3. cancel oo output answer
# unfence also has this built in
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
  if [ -n "$NO_CACHE" ]; then
    return 0
  fi
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
  local tmp_json tmp_req last_role
  tmp_json=$(mktemp_reg)
  tmp_req=$(mktemp_reg)

  # Read first line to check for header
  read -r first_line
  if [[ "$first_line" == "${PIPELINE_MAGIC_HEADER}" ]]; then
    cat > "$tmp_json"
  else
    printf "%s\n" "$first_line" > "$tmp_json"
    cat >> "$tmp_json"
  fi

  # Contract: _infer takes a JSON array of chat messages.
  if ! jq -e 'type == "array"' < "$tmp_json" >/dev/null 2>&1; then
    echo "[]"
    return 0
  fi

  # If already resolved, pass through unchanged.
  last_role=$(jq -r 'if length > 0 then .[-1].role // empty else empty end' < "$tmp_json")
  if [ "$last_role" != "user" ]; then
    cat "$tmp_json"
    return 0
  fi

  local api_key="${OPENAI_API_KEY:-}"
  local endpoint="${VIA_API_CHAT_BASE}/v1/chat/completions"

  jq \
    --arg model "${VIA_MODEL:-gpt-3.5-turbo}" \
    --argjson thinking "${ENABLE_THINKING:-false}" \
    --argjson max_tokens "${VIA_MAX_TOKENS:-24000}" \
    '{
      model: $model,
      messages: .,
      max_tokens: $max_tokens,
      thinking: $thinking,
      thinking_budget_tokens: 20000
    }' < "$tmp_json" > "$tmp_req"

  local server_model fingerprint request_hash cache_dir cache_file response_json
  server_model=$(curl -fsS "${VIA_API_CHAT_BASE}/v1/models" |
    jq -r '.data[0].id // .id // "local_model"' 2>/dev/null || printf "local_model")

  fingerprint=$(printf "%s" "$server_model" | tr '/:' '__')
  request_hash=$(openssl dgst -sha256 < "$tmp_req" | awk '{print $2}')

  cache_dir=$(_find_cache_dir)
  cache_file=""
  if [ -n "$cache_dir" ]; then
      mkdir -p "$cache_dir"
      cache_file="${cache_dir}/${fingerprint}:${request_hash}.json"
  fi

  if  [ -n "$cache_dir" ] && [ -f "$cache_file" ]; then
    printf "🎯" >&2
    response_json=$(cat "$cache_file")
  else
    printf "💭" >&2
    response_json=$(curl -fsS -X POST "$endpoint" \
                         -H "Authorization: Bearer $api_key" \
                         -H "Content-Type: application/json" \
                         -d @"$tmp_req") || {
      return 1
    }
    # log_warn "response_json=$response_json"
  fi

  # Contract: OpenAI-compatible chat completion response with non-empty assistant content.
  local assistant_content
  assistant_content=$(
    printf "%s" "$response_json" | jq -er '
      .choices[0].message.content
      | select(type == "string" and length > 0)
    ' 2>/dev/null
  ) || {
    echo "🦶infer: ERROR: empty or missing assistant content in chat completion response" >&2
    printf "%s" "$response_json" | jq -c '{id, object, choices, error}' 2>/dev/null || true
    return 1
  }

  # Only cache responses that passed validation.
  if [ -n "$cache_file" ] && [ ! -f "$cache_file" ]; then
    local tmp_cache
    tmp_cache=$(mktemp_reg "${cache_file}.tmp.XXXXXX")
    printf "%s" "$response_json" > "$tmp_cache" && mv "$tmp_cache" "$cache_file"
  fi

  local assistant_msg_json
  assistant_msg_json=$(printf "%s" "$assistant_content" | jq -R -s -c '{role: "assistant", content: .}')

  # Combine the original array with the new assistant message
  jq -s -c '.[0] + .[1:]' <(cat "$tmp_json") <(printf "%s" "$assistant_msg_json")
  local infer_status=$?
  return $infer_status
}

function hx() {
    if [ "$1" == "cache" ] && [ "$2" == "clear" ]; then
        cache_dir=$(_find_cache_dir)
        if [ -z "$cache_dir" ]; then
            echo "no cache is available"
            return 1;
        fi
        echo "⚠️ Are you sure you want to remove $cache_dir? (y/N)" >&2
        read -r -p "Delete directory? (y/N): " reply < /dev/tty
        if [[ "$reply" =~ ^[Yy]$ ]]; then
            rm -rf -- "$cache_dir"
            echo "🗑️  Cache  cleaed."
        else
            echo "🚫 Cancelled."
        fi
        return 0
    elif [ "$1" == "cache" ] && [ "$2" == "show" ]; then
        cache_dir=$(_find_cache_dir)
        echo "$cache_dir"
        return 0
    elif [ "$1" == "cache" ] && [ "$2" == "disable" ]; then
        export NO_CACHE=1
        echo "⚠️ Cache disabled."
        return 0
    elif [ "$1" == "cache" ] && [ "$2" == "enable" ]; then
        export NO_CACHE=""
        unset NO_CACHE
        echo "⚠️ Cache enabled."
        return 0
    elif [ "$1" == "disable" ]; then
        source "$(dirname "${BASH_SOURCE[0]}")/commands/disable"
    elif [ "$1" == "answer" ] || [ "$1" == "enable" ]; then
        source ~/wip/answer/commands/enable
    else
        echo "usage: hx cache {clear|show|enable}"
        return 1
    fi
}

