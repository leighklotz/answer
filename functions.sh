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

# MIME Headers
PIPELINE_MAGIC_HEADER="Content-Type: application/x-llm-history+json"

# Tempfile Registry
# --- SHARED WORKSPACE SETUP ---

function _ensure_workspace() {
    # Initialize a shared temporary workspace ONLY when a temp file is actually requested.
    if [[ -z "$HALLUX_RUN_DIR" ]] || [[ ! -d "$HALLUX_RUN_DIR" ]]; then
        export HALLUX_RUN_DIR="$(mktemp -d "${TMPDIR:-/tmp}/hallux_run.XXXXXX")"
        # Track the process ID that created this directory
        export HALLUX_RUN_OWNER_PID="$BASHPID"
        log_trace "Creating $HALLUX_RUN_DIR pid=$HALLUX_RUN_OWNER_PID"
    fi
    
    # Register the cleanup trap only in processes that are actually using temp files.
    # (Setting this inside the function prevents hijacking interactive shell traps)
    trap '_cleanup_run_dir' EXIT INT SIGINT TERM SIGTERM HUP SIGHUP
}

function _mktemp_reg() {
    local tmp
    _ensure_workspace
    
    # Force the template to be created INSIDE our shared run directory
    if ! tmp=$(mktemp "$HALLUX_RUN_DIR/$1"); then
        log_and_exit 1 "failed to create temp file"
    fi
    log_debug "mktemp $tmp"
    MKTEMP_REG="$tmp"
    return 0
}

function _mktemp_reg_lit() {
    local tmp
    # For literal paths (like caching alongside the target file), use standard mktemp.
    # We do not track these in the run dir because they are used for atomic file moves.
    if ! tmp=$(mktemp "$1"); then
        log_and_exit 1 "failed to create temp file"
    fi
    log_debug "mktemp $tmp"
    MKTEMP_REG="$tmp"
    return 0
}

function _cleanup_run_dir() {
    # If a subshell or a downstream pipeline script exits, it inherits the trap 
    # but its $BASHPID will not match the original owner.
    if [[ "$BASHPID" != "$HALLUX_RUN_OWNER_PID" ]]; then
        return 0
    fi
    
    if [[ -d "$HALLUX_RUN_DIR" ]]; then
        log_trace "Cleaning up workspace: $HALLUX_RUN_DIR"
        rm -rf -- "$HALLUX_RUN_DIR"
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


# use `builtin help` if you want native bash help command
function help ()
{
    help.sh "$@"
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
  _mktemp_reg 'infer.XXXXXX.json' && tmp_json="$MKTEMP_REG"
  _mktemp_reg 'response.XXXXXX.json' && tmp_req="$MKTEMP_REG"

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
      thinking_budget_tokens: 5000
    }' < "$tmp_json" > "$tmp_req"

  local server_model fingerprint request_hash cache_dir cache_file response_json
  server_model=$(curl -fsS "${VIA_API_CHAT_BASE}/v1/models" |
    jq -r '.data[0].id // .id // "local_model"' 2>/dev/null || printf "local_model")

  fingerprint=$(printf "%s" "$server_model" | tr '/:' '__')
  request_hash=$(openssl dgst -sha256 < "$tmp_req" | awk '{print $2}')

  cache_dir=$(_find_cache_dir)
  cache_file=""
  if [ -n "$cache_dir" ]; then
      log_trace "Creating cache_dir=$cache_dir"
      mkdir -m 700 -p "$cache_dir"
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
    _mktemp_reg_lit "${cache_file}.tmp.XXXXXX" && tmp_cache="$MKTEMP_REG"
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
    if [ "$1" == "cache" ] && [[ "$2" =~ ^(clear|show|disable|enable)$ ]]; then
        case "$2" in
            clear)
                cache_dir=$(_find_cache_dir)
                if [ -z "$cache_dir" ]; then
                    echo "no cache is available"
                    return 1;
                fi
                echo "⚠️ Are you sure you want to remove $cache_dir? (y/N)" >&2
                read -r -p "Delete directory? (y/N): " reply < /dev/tty
                if [[ "$reply" =~ ^[Yy]$ ]]; then
                    rm -rf -- "$cache_dir"
                    echo "🗑️ Cache cleared."
                else
                    echo "🚫 Cancelled."
                fi
                return 0
            ;;
            show)
                cache_dir=$(_find_cache_dir)
                echo "$cache_dir"
                return 0
                ;;
            disable)
                export NO_CACHE=1
                echo "⚠️ Cache disabled."
                return 0
                ;;
            enable)
                unset NO_CACHE
                echo "⚠️ Cache enabled."
                return 0
                ;;
        esac
    elif [ "$1" == "disable" ]; then
        source "$(dirname "${BASH_SOURCE[0]}")/commands/disable"
    elif [ "$1" == "enable" ]; then
        source ~/wip/answer/commands/enable
    elif [ "$1" == "answer" ]; then
        cache_dir="$(_find_cache_dir)"
        cache_fn="$(ls -t "$cache_dir"/ | head -1)"
        cat "${cache_dir}/${cache_fn}" | ~/wip/answer/commands/answer.sh
    elif [ "$1" == "why" ]; then
        cache_dir="$(_find_cache_dir)"
        cache_fn="$(ls -t "$cache_dir"/ | head -1)"
        cat "${cache_dir}/${cache_fn}" | ~/wip/answer/commands/why.sh
    elif [ "$1" == "what" ]; then
        cache_dir="$(_find_cache_dir)"
        cache_fn="$(ls -t "$cache_dir"/ | head -1)"
        cat "${cache_dir}/${cache_fn}" | ~/wip/answer/commands/what.sh
    else
        echo "usage: hx {cache [clear|show|disable|enable]|answer|why|what|disable|enable}" >&2
        return 1
    fi
}

alias to_awk='help output the calculation in a code fence as an awk script to be used as stdin to \`awk -f -\`'
alias to_bash='help output the calculation in a code fence as a bash script to be used as stdin to \`bash\`'
alias to_python='help output the calculation in a code fence as a python script to be used as stdin to \`python\`'
