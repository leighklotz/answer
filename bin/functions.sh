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

# --- SHARED WORKSPACE SETUP ---
function _ensure_workspace() {
    # Initialize a shared temporary workspace ONLY when a temp file is actually requested.
    if [[ -z "$HALLUX_RUN_DIR" ]] || [[ ! -d "$HALLUX_RUN_DIR" ]]; then
        export HALLUX_RUN_DIR
        HALLUX_RUN_DIR="$(mktemp -d "${TMPDIR:-/tmp}/hallux_run.XXXXXX")"
        # Track the process ID that created this directory
        export HALLUX_RUN_OWNER_PID="$BASHPID"
        log_trace "Creating $HALLUX_RUN_DIR pid=$HALLUX_RUN_OWNER_PID"
    fi
    
    # Register the cleanup trap only in processes that are actually using temp files.
    # (Setting this inside the function prevents hijacking interactive shell traps)
    trap '_cleanup_run_dir' EXIT INT SIGINT TERM SIGTERM HUP SIGHUP
}

function _mktemp_reg() {
    local template="$1"
    local literal="$2"
    local tmp
    local prefix
    if [ -z "$literal" ]; then
        _ensure_workspace
        prefix="$HALLUX_RUN_DIR/"
    else
        prefix=""
    fi

    # macOS mktemp can fail when a path and complex template are passed together.
    # The "cheapest fix" for cross-platform compatibility is to use -u (unsafe/dry-run) 
    # with the full pattern, then create it using 'touch'. This avoids mkstemp errors.
    if ! tmp=$(mktemp "${prefix}${template}" 2>/dev/null); then
        # Fallback for macOS where mktemp is picky about templates:
        # Generate a unique path via -u, then touch it to create the file safely.
        tmp=$(mktemp -u "${prefix}${template%.*}XXXXXX.${1##*.}" 2>/dev/null || \
               mktemp -u "${prefix}${template}" 2>/dev/null)
    fi

    if [[ ! -f "$tmp" ]]; then
        touch "$tmp" 2>/dev/null || log_and_exit 1 "failed to create temp file: $tmp"
    fi

    log_debug "mktemp $tmp"
    MKTEMP_REG="$tmp"
    return 0
}

function _mktemp_reg_lit() {
    _mktemp_reg "$1" "1"
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
      enable_thinking: $thinking,
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
    log_trace "$(cat "$tmp_req")"
    printf "✨" >&2
    local auth_flags
    if [ -n "$api_key" ]; then
        printf -v auth_flags '-H "Authorization: Bearer %s"' "${api_key}"
    fi
    # shellcheck disable=SC2086
    response_json=$(curl -fsS -X POST "$endpoint" \
                         $auth_flags \
                         -H "Content-Type: application/json" \
                         -d @"$tmp_req") || {
      return 1
    }
    if jq -e '.choices[0]?.message?.reasoning_content != null' <<< "$response_json" >/dev/null 2>&1; then
        printf "🧠 ENABLE_THINKING=%s" "${ENABLE_THINKING}" >&2
    fi
  fi

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

### user-level Functions and aliases

function hx() {
    if [[ "$1" == "cache" ]]; then
        case "$2" in
            clear)
                local cache_dir=$(_find_cache_dir)
                [[ -z "$cache_dir" ]] && { echo "no cache available"; return 1; }
                echo "⚠️ Are you sure you want to remove $cache_dir? (y/N)" >&2
                read -r -p "Delete directory? (y/N): " reply < /dev/tty
                if [[ "$reply" =~ ^[Yy]$ ]]; then
                    rm -rf -- "$cache_dir" && echo "🗑️ Cache cleared."
                else
                    echo "🚫 Cancelled."
                fi
                return 0
                ;;
            show)    printf "%s\n" "$(_find_cache_dir)"; return 0 ;;
            disable) export NO_CACHE=1; echo "⚠️ Cache disabled."; return 0 ;;
            enable)  unset NO_CACHE; echo "⚠️ Cache enabled."; return 0 ;;
            *)       echo "Unknown cache option: $2" ;;
        esac
        return 0 # Exit hx after handling cache logic
    fi

    # Handle all other primary commands via case
    case "$1" in
        enable|disable) source ~/wip/answer/bin/commands/${1} ;;
        why) 
            local c_dir="$(_find_cache_dir)"
            local c_fn="$(ls -t "$c_dir"/ | head -1 2>/dev/null)"
            [[ -n "$c_fn" ]] && cat "${c_dir}/${c_fn}" | ~/wip/answer/bin/commands/"${1}.sh" || echo "No cache file found."
            ;;
        what)   
            local c_dir="$(_find_cache_dir)"
            local c_fn="$(ls -t "$c_dir"/ | head -1 2>/dev/null)"
            [[ -n "$c_fn" ]] && cat "${c_dir}/${c_fn}" | ~/wip/answer/bin/commands/what.sh || echo "No cache file found."
            ;;
        model)  _get_model_name ;;
        *)      echo "usage: hx [cache [clear|show|disable] | enable|disable|why|what|model]" >&2; return 1 ;;
    esac
}

function _get_model_name() {
    local endpoint="${VIA_API_CHAT_BASE}/props"
    local model_name
    model_name="$(curl -s "${endpoint}" "${AUTHORIZATION_PARAMS[@]}" | jq -e -r .model_alias 2> /dev/null)"
    if [ -z "$model_name" ]; then
        model_name=$(curl -s "${VIA_API_MODEL_INFO_ENDPOINT}" "${AUTHORIZATION_PARAMS[@]}" | jq -e -r .model_name 2> /dev/null)
    fi
    if [ "${model_name}" == "null" ]; then
        model_name="${MODEL_NAME_OVERRIDE:-None}"
    fi
    model_name="$(printf "%s" "${model_name}"| sed -e 's/-/_/g' | sed -e 's/\.gguf//')"
    printf "%s\n" "${model_name}" 
    return 0
}

# use `builtin help` if you want native bash help command
function help ()
{
    help.sh "$@"
}

alias to_awk='help output the calculation in a code fence as an awk script to be used as stdin to \`awk -f -\`'
alias to_bash='help output the calculation in a code fence as a bash script to be used as stdin to \`bash\`'
alias to_python='help output the calculation in a code fence as a python script to be used as stdin to \`python\`'
