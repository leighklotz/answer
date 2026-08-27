# shellcheck shell=bash

# source this file to define the functions

# Require bash 4+
if [ "${BASH_VERSINFO[0]}" -lt 4 ]; then
    echo "${HALLUX_ICON} ERROR: bash 4 or later is required (running ${BASH_VERSION})." >&2
    return 1 2>/dev/null
fi

# Check if ask.sh is available
if ! command -v ask.sh &> /dev/null; then
    echo "${HALLUX_ICON} $0: WARN: ask.sh is not on the PATH.  Please add the directory containing ask.sh to your PATH environment variable." >&2
fi

# Source env.sh if variables are not already defined
if [ -z "${VIA_API_CHAT_BASE}" ] && [ -f "$(dirname "${BASH_SOURCE[0]}")/env.sh" ]; then
    source "$(dirname "${BASH_SOURCE[0]}")/env.sh"
fi

# MIME Headers
PIPELINE_MAGIC_HEADER="Content-Type: application/x-llm-history+json"
PIPELINE_TEXT_CONVO_HEADER="Content-Type: text/x-llm-history+plain"
PIPELINE_REASONING_CONVO_HEADER="Content-Type: text/x-llm-reasoning+plain"
PIPELINE_TEXT_PLAIN_HEADER="Content-Type: text/plain"

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
    # 1. Ensure we are in the owner process to prevent subshell interference
    [[ "$BASHPID" != "$HALLUX_RUN_OWNER_PID" ]] && return 0
    
    # 2. Use a local variable for the dir to avoid issues if HALLUX_RUN_DIR is unset mid-flight
    local target="$HALLUX_RUN_DIR"

    if [[ -n "$target" && -d "$target" ]]; then
        log_trace "Cleaning up workspace: $target"
        # 3. Use -- to prevent filenames starting with '-' from being treated as flags
        # and suppress errors in case another process beat us to it (the 'rm' race)
        rm -rf -- "$target" 2>/dev/null || true
    fi

    # 4. Unset the variable so subsequent calls don't try to re-clean or find a non-existent dir
    unset HALLUX_RUN_DIR
}

function _find_cache_dir () {
  if [ -n "$HX_NO_CACHE" ]; then
    return 0
  fi
  local current_dir
  current_dir="$(pwd)"

  # Traverse upward looking strictly for a .hallux workspace directory anchor.
  while [ "$current_dir" != "/" ]; do
    if [ -d "${current_dir}/.hallux" ]; then
      printf "%s/.hallux/cache" "$current_dir"
      return 0
    fi
    current_dir="$(dirname "$current_dir")"
  done

  # Ultimate system-standard fallback location.
  printf "%s/.config/hallux/cache" "${HOME}"
}

function _get_newest_cache_file() {
    local dir="$1"
    [[ -d "$dir" ]] || return 1
    
    if stat --version >/dev/null 2>&1; then
        # GNU find / Linux version
        find "$dir" -maxdepth 1 -type f -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2-
    else
        # macOS / BSD version using stat
        find "$dir" -maxdepth 1 -type f -exec stat -f "%m %N" {} + | sort -rn | head -n 1 | cut -d' ' -f2-
    fi
}

function _infer () {
  local tmp_json tmp_req last_role
  _mktemp_reg 'infer.XXXXXX.json' && tmp_json="$MKTEMP_REG"
  _mktemp_reg 'response.XXXXXX.json' && tmp_req="$MKTEMP_REG"

  # Read first line to check for header
  read -r first_line
  if [[ ! -w "$tmp_json" ]]; then
         log_and_exit 2 "_infer: cancelled"
  fi
  if [[ "$first_line" == "${PIPELINE_MAGIC_HEADER}" ]]; then
    cat > "$tmp_json"
  else
    printf "%s\n" "$first_line" > "$tmp_json"
    cat >> "$tmp_json"
  fi

  # Contract: _infer takes a JSON array of chat messages.
  if ! jq -e 'type == "array"' < "$tmp_json" >/dev/null 2>&1; then
    log_and_exit 1 "_infer takes a JSON array of chat messages."
  fi

  # If already resolved, pass through unchanged.
  last_role=$(jq -r 'if length > 0 then .[-1].role // empty else empty end' < "$tmp_json")
  if [ "$last_role" != "user" ]; then
    cat "$tmp_json"
    return 0
  fi

  local api_key="${OPENAI_API_KEY:-}"
  local endpoint="${VIA_API_CHAT_BASE}/v1/chat/completions"
  local server_model="$(_get_model_name)"

  if [ -z "$server_model" ]; then
      log_warn "$VIA_API_CHAT_BASE has no default model loaded: using 'default'"
      server_model='default'
  fi
    
  log_info "model=$server_model"

  # TODO: Should we map these for model agnosticism
  # or let the user set them individually as needed.
  # For qwen3.8-27b:
  # - REASONING_EFFORT=low -> THINKING_BUDGET=2000
  # - REASONING_EFFORT=medium -> THINKING_BUDGET=8000
  # - REASONING_EFFORT=xhigh -> THINKING_BUDGET=32768
  jq \
    --arg server_model "$server_model" \
    --argjson thinking "${ENABLE_THINKING:-true}" \
    --argjson max_tokens "${VIA_MAX_TOKENS:-24000}" \
    --argjson thinking_budget "${THINKING_BUDGET:-8000}" \
    --arg reasoning_effort "${REASONING_EFFORT:-medium}" \
    --arg reasoning_budget: $'\n[Budget reached. Transitioning to final response...]\n' \
    '{
      model: $server_model,
      messages: .,
      max_tokens: $max_tokens,
      enable_thinking: $thinking,
      thinking_budget_tokens: $thinking_budget,
      chat_template_kwargs: { reasoning_effort: $reasoning_effort }
}' < "$tmp_json" > "$tmp_req"

  local fingerprint request_hash cache_dir cache_file response_json

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
    log_trace "cache_file=$cache_file"
    printf "$CACHE_HIT_ICON" >&2
    response_json=$(cat "$cache_file")
  else
    [ -n "$LOG_QUERIES" ] && log_trace "request=$(cat "$tmp_req")"
    printf "%s" "$INFERENCE_ICON" >&2
    local auth_flags
    if [ -n "$api_key" ]; then
        printf -v auth_flags '-H "Authorization: Bearer %s"' "${api_key}"
    fi
    log_trace "endpoint=$endpoint"
    # shellcheck disable=SC2086
    response_json=$(curl -fsS -X POST "$endpoint" \
                         $auth_flags \
                         -H "Content-Type: application/json" \
                         -d @"$tmp_req") || {
      return 1
    }
    [ -n "$LOG_QUERIES" ] && log_trace "response_json=$response_json"
    if jq -e '.choices[0]?.message?.reasoning_content != null' <<< "$response_json" >/dev/null 2>&1; then
        printf "%s" "$THINK_ICON" >&2
    fi
  fi

  local assistant_content
  assistant_content=$(
    printf "%s" "$response_json" | jq -er '
      .choices[0].message.content
      | select(type == "string" and length > 0)
    ' 2>/dev/null
  ) || {
      local dat
      dat=$(jq -c '{id,object,choices,error}' <<<"$response_json" 2>/dev/null)
      log_error "infer: empty or missing assistant content in chat completion response: ${dat}"
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
}

# executes the previous bash command line again, but through bx and with stderr redirected.
# Use in a pipe such as `hx again | ask what went wrong`
function _hx_again() {
    local cmd
    cmd=$(fc -ln -1)
    bx ${cmd/#bx /} 2>&1
}

# TODO: Find a better way to pick a model of multiple models are loaded
# TODO: `hx models` or `hx model` might take filtering arguments (words to require in model name)
function _get_model_name() {
    local model_names
    if [ -z "$model_names" ]; then
        model_names="$HX_MODEL"
    fi
    if [ -z "$model_names" ]; then
        model_names="$(curl -fsS "${VIA_API_CHAT_BASE}/models" "${AUTHORIZATION_PARAMS[@]}" | jq -r ' . | .data[] | select(.status.value == "loaded") | .id')"
    fi
    if [ -z "$model_names" ] || [ "$model_names" == 'llama-server' ]; then
        model_names=$(curl -s "${VIA_API_MODEL_INFO_ENDPOINT}" "${AUTHORIZATION_PARAMS[@]}" | jq -r -e -r .model_name 2> /dev/null)
    fi
    if [ -z "$model_names" ] || [ "$model_names" == 'llama-server' ]; then
        model_names="gpt-3.5"
    fi
    printf "%s\n" "${model_names}" | head -1
    return 0
}

function _load_model() {
    local model="$1"
    if [[ -z "$model" ]]; then
        echo "Usage: _load_model <model_name>" >&2
        return 1
    fi

    log_info "Loading model: $model"
    local endpoint="${VIA_API_CHAT_BASE}/models/load"

    curl -fsS -X POST "$endpoint" \
        -H "Content-Type: application/json" \
        -d "$(printf '{"model": "%s"}' "$model")" > /dev/null || {
            log_error "Failed to load model: $model"
            return 1
        }

    echo "$GREEN_CHECK_ICON $model loaded" >&2
}

function _unload_model() {
    local model="$1"
    if [[ -z "$model" ]]; then
        echo "Usage: _unload_model <model_name>" >&2
        return 1
    fi

    log_info "Unloading model: $model"
    local endpoint="${VIA_API_CHAT_BASE}/models/unload"

    curl -fsS -X POST "$endpoint" \
        -H "Content-Type: application/json" \
        -d "$(printf '{"model": "%s"}' "$model")" > /dev/null || {
            log_error "Failed to unload model: $model"
            return 1
        }

    echo "${GREEN_CHECK_ICON} $model unloaded" >&2
}

function _strip_markdown_fence() {
    sed -e '1{/^```[A-Za-z0-9_-]*[[:space:]]*$/d;}' -e '${/^```[[:space:]]*$/d;}'
}
