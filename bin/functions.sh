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

if [[  "$(command -v ask.sh)" != *answer* ]]; then
    echo "🦶$0: WARN: Wrong ask.sh is on the PATH.  Please use 'hx disable' followed by 'hx enable'." >&2
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

  jq \
    --arg server_model "$server_model" \
    --argjson thinking "${ENABLE_THINKING:-true}" \
    --argjson max_tokens "${VIA_MAX_TOKENS:-24000}" \
    --argjson thinking_budget "${THINKING_BUDGET:-500}" \
    '{
      model: $server_model,
      messages: .,
      max_tokens: $max_tokens,
      enable_thinking: $thinking,
      thinking_budget_tokens: $thinking_budget,
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
    printf "🎯" >&2
    response_json=$(cat "$cache_file")
  else
    [ -n "$LOG_QUERIES" ] && log_trace "request=$(cat "$tmp_req")"
    printf "✨" >&2
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
        printf "🧠" >&2
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
}


### user-level Functions and aliases
function hx() {
    # Handle provenance Subcommand
    if [[ "$1" == "provenance" ]]; then
        _hx_provenance $2 $3
        return 0
    elif [[ "$1" == "cache" ]]; then
        shift # Remove 'cache' from arguments, now subcommands are in $@
        _hx_cache "$@"
        return $?
    fi

    # Handle Main Commands
    case "$1" in
        enable | disable)
            local cmd_file="$HOME/wip/answer/bin/commands/${1}"
            if [[ -f "$cmd_file" ]]; then
                # shellcheck disable=SC1090
                source "$cmd_file"
            else
                echo "Error: Command script $cmd_file not found." >&2
                return 1
            fi
        ;;

        again)
            # Executes the previous bash command line again, but through bx and with stderr redirected.
            # Use in a pipe such as `hx again | ask what went wrong`
            _hx_again
            ;;

        why | what | cat | describe | stats)
            local c_dir="$(_find_cache_dir)"
            local latest_f
            latest_f=$(_get_newest_cache_file "$c_dir")

            if [[ -n "$latest_f" && -f "$latest_f" ]]; then
                cat "$latest_f" | ~/wip/answer/bin/commands/"${1}.sh"
            else
                echo "No cache file found for '$1'." >&2
                return 1
            fi
        ;;

        model)
            shift
            ~/wip/answer/bin/commands/model.sh "$@"
        ;;

        set-model)
            shift
            HX_MODEL=$(~/wip/answer/bin/commands/model.sh "$@") && {
                export HX_MODEL="$HX_MODEL"
                echo "🦶export HX_MODEL=$HX_MODEL" >&2
            } || return 1
        ;;

        models)
            shift
            ~/wip/answer/bin/commands/models.sh "$@"
        ;;

        *)
            echo "usage: hx [cache [clear|show|disable] | enable|disable|why|what|cat|describe|stats|model|models|set-model]" >&2
            return 1
        ;;
    esac
}

function _hx_cache() {
    case "$1" in
        clear)
            local cache_dir
            cache_dir=$(_find_cache_dir)
            
            if [[ -z "$cache_dir" || ! -d "$cache_dir" ]]; then 
                echo "❌ No valid cache directory found." >&2
                return 1
            fi

            # Safety check: prevent accidental deletion of root or home if _find_cache_dir fails catastrophically
            if [[ "$cache_dir" == "/" || "$cache_dir" == "$HOME" ]]; then
                echo "❌ Error: Cache directory is a protected system path." >&2
                return 1
            fi

            printf "⚠️ Are you sure you want to remove %s?\n" "$cache_dir" >&2
            read -r -p "Delete directory? (y/N): " reply < /dev/tty
            if [[ "$reply" =~ ^[Yy]$ ]]; then
                rm -- "$cache_dir"/*.json && echo "🗑️ Cache cleared." || echo "❌ Deletion failed." >&2
            else
                echo "🚫 Cancelled."
            fi
            ;;

        show)
            printf "%s\n" "$(_find_cache_dir)"
            return 0
            ;;

        enable|disable)
            if [[ "$1" == "disable" ]]; then
                export HX_NO_CACHE=1
                echo "⚠️ Cache disabled (session-wide)."
            else
                unset HX_NO_CACHE
                echo "⚠️ Cache enabled (session-wide)."
            fi
            return 0
            ;;

        *)
            echo "Unknown cache option '$1': (clear|show|enable|disable)" >&2
            return 1
            ;;
    esac
}

# executes the previous bash command line again, but through bx and with stderr redirected.
# Use in a pipe such as `hx again | ask what went wrong`
function _hx_again() {
    local cmd
    cmd=$(fc -ln -1)
    bx ${cmd/#bx /} 2>&1
}

function _hx_provenance() {
    case "$1" in
        add)
            shift
            case "$1" in 
                what|why|response|describe|-)
                    local last_cmd prompt_str subcmd
                    last_cmd=$(fc -nl -2 | sed 's/^[[:space:]]*//')
                    prompt_str="${PS1@P}"
                    subcmd="$1"

                    local emoji
                    declare -A emoji=([what]="💭" [why]="🧠" [response]="↩️" [describe]="📜" [-]="➡️️")
                    declare -A ctype=([what]="$PIPELINE_TEXT_CONVO_HEADER" [why]="$PIPELINE_REASONING_CONVO_HEADER" [response]="$PIPELINE_MAGIC_HEADER" [describe]="$PIPELINE_TEXT_PLAIN_HEADER" [-]="$PIPELINE_TEXT_PLAIN_HEADER")

                    local subcmd_emoji
                    local content_type_header
                    subcmd_emoji="${emoji[$subcmd]}"
                    content_type_header="${ctype[$subcmd]}"                    

                    printf "💾 hx provenance %s %s | git notes --ref=provenance/hallux append 📌\n" "$subcmd" "$subcmd_emoji" >&2

                    local hx_out
                    if [ "$subcmd" == "-" ]; then
                        if [ -t 0 ]; then
                            echo "Provide hx provenance add input:" >&2
                        fi
                        hx_out="$(cat)"
                    else
                        hx_out=$(hx $subcmd 2>/dev/null || echo "[hx $subcmd failed or missing]")
                    fi

                    printf "%s%s\n%s\n%s\n\n" \
                        "$prompt_str" \
                        "$last_cmd" \
                        "${content_type_header}" \
                        "$hx_out" \
                        | git notes --ref=provenance/hallux append -F -
                    return 0
                    ;;
                "")
                    echo "usage: hx provenance add [cat|what|why]" >&2
                    ;;

                *) echo "hx provenance add: unknown subcmd '$1'" >&2
                   return 1
                   ;;
            esac
        ;;
        show)
            # Instantly prints out your clean chronological append log for HEAD or a specific hash
            git notes --ref=provenance/hallux show "$2"
            return 0
            ;;
            
        refs)
            # Scans the repo and lists hashes that have your tool's data attached
            git notes --ref=provenance/hallux list
            return 0
            ;;
            
        list)
            # Decorated list that slices the first and last 20 characters of the first note line
            git notes --ref=provenance/hallux list | while read -r note_hash commit_hash; do
                local log_line note_first_line preview
                log_line=$(git log -1 --oneline "$commit_hash")
                note_first_line=$(git notes --ref=provenance/hallux show "$commit_hash" 2>/dev/null | head -n 1)
                
                if (( ${#note_first_line} <= 43 )); then
                    preview="$note_first_line"
                else
                    preview="${note_first_line:0:20}...${note_first_line: -20}"
                fi
                
                local color_cyan='\x1b[36m'
                local nc='\x1b[0m'
                printf "%s 📌${color_cyan}%s${nc}\n" "$log_line" "$preview"
            done
            return 0
            ;;
            
        *)
            echo "usage: hx provenance [ show | refs | list | add [ what | why | cat ] ]" >&2
            return 1
            ;;
    esac
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

# use `builtin help` if you want native bash help command
function help ()
{
    help.sh "$@"
}
