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
    s=$?
    if [ $s -ne 0 ] && [ -z "${quiet}" ] ; then
        echo "🦶bx: ERROR: bx.sh failed with exit code $s" >&2
        return 1
    fi
}

unfence ()
{
    unfence.sh "$@"
    s=$?
    if [ $s -ne 0 ]; then
        echo "🦶ERROR: unfence.sh failed with exit code $s" >&2
        return 1
    fi
}

function tools ()
{
    local s

    #  pass through to tools.sh which will error appropriately.
    tools.sh "$@"
    s=$?

    if [ $s -ne 0 ]; then
        echo "🦶ERROR: tools.sh failed with exit code $s" >&2
        return $s
    fi
}


function pipetest()
{
    # Sanity Check: If running interactively but no prompt provided, warn of potential hang
    if [ -t 0 ] && [[ "$*" != *"-i"* ]]; then
        echo "🦶pipetest: No user query detected in arguments; waiting for STDIN..." >&2
    fi

    local user_query="$*"

    # 1. Capture stdin into a temporary file – this allows very large input.
    local tmpdir tmpfile
    if ! tmpdir=$(mktemp -d 2>/dev/null) ; then
        printf >&2 "pipetest: could not create temporary directory\n"
        return 1
    fi
    trap 'rm -rf "$tmpdir"' EXIT
    if ! tmpfile=$(mktemp --tmpdir="$tmpdir" pipetest.XXXXXX 2>/dev/null) ; then
        printf >&2 "pipetest: could not create temporary file\n"
        return 1
    fi

    # 2. Read all of stdin into the temp file.
    cat >"$tmpfile"

    local reply
    local pager

    # Auto-detect the best available viewing tool
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
    ${pager} "$tmpfile" 1>&2

    # Safe interactive prompt from /dev/tty (avoids the racing subshell read)
    read -r -p "🤖 ${user_query}: Y or N? " reply < /dev/tty

    printf "\n" 1>&2
    case "${reply,,}" in
        y*)
            cat "$tmpfile"
        ;;
        *)
            printf "🚫 discarded\n" 1>&2
        ;;
    esac
}

# use `builtin help` if you want native bash help command
help () 
{ 
    help.sh "$@"
}

function find_cache_dir () {
  local current_dir
  current_dir="$(pwd)"

  # 1. Traverse upward looking strictly for a .hallux workspace directory anchor
  while [ "$current_dir" != "/" ]; do
    if [ -d "${current_dir}/.hallux" ]; then
      # Found the workspace anchor! Return the path with the target cache directory appended.
      printf "%s/.hallux/cache" "$current_dir"
      return 0
    fi
    current_dir="$(dirname "$current_dir")"
  done

  # 2. Fall back to the user home baseline path if the folder anchor exists
  if [ -d "${HOME}/.hallux" ]; then
    printf "%s/.hallux/cache" "${HOME}"
    return 0
  fi

  # 3. Ultimate system-standard fallback location
  printf "%s/.config/hallux/cache" "${HOME}"
}

function infer () {
  local stdin_content
  stdin_content=$(cat)

  # CLEAN PIPELINE STRIP: Safely strip the magic header line using native Bash string expansion
  local clean_stdin
  if [[ "$stdin_content" == "${PIPELINE_MAGIC_HEADER}"* ]]; then
    clean_stdin="${stdin_content#${PIPELINE_MAGIC_HEADER}}"
    # Strip any leading newlines left over right after the header line split
    clean_stdin="${clean_stdin#$'\n'}"
  else
    clean_stdin="$stdin_content"
  fi

  # Ensure it is a valid JSON array or object
  if [ -z "$clean_stdin" ] || ! jq -e '.' <<< "$clean_stdin" >/dev/null 2>&1; then
    echo "[]"
    return 0
  fi

  # Extract the last message's role to check if execution is required
  local last_role
  last_role=$(jq -r 'if type == "array" and length > 0 then .[-1].role else empty end' <<< "$clean_stdin" 2>/dev/null)

  # NO-OP: If the last message is already an assistant reply, pass it straight through
  if [ "$last_role" != "user" ]; then
    printf "%s\n" "$clean_stdin"
  fi

  # --- ACTIVE INFERENCE ENGINE ---
  local api_key="${OPENAI_API_KEY:-}"
  local endpoint="${VIA_API_CHAT_BASE}/v1/chat/completions"

  # Build OpenAI/llama.cpp compliant body
  local request
  request=$(jq -n --argjson messages "$clean_stdin" --arg model "gpt-3.5-turbo" --argjson max_tokens 4096 \
    '{model: $model, thinking: true, max_tokens: $max_tokens, messages: $messages, top_k: 20, top_p: 0.95, min_p: 0.1, tfs_z: 1, typical_p: 1.0, repeat_penalty: 1.0, repeat_last_n: 1024, presence_penalty: 0.0, frequency_penalty: 0.0, seed: -1}')

  # Fetch active model for cache footprint mapping
  local server_model fingerprint request_hash cache_match
  server_model=$(curl -s "${VIA_API_CHAT_BASE}/v1/models" | jq -r '.data[0].id // .id // "local_model"')
  fingerprint=$(printf "%s" "$server_model" | tr '/' '_')
  request_hash=$(printf "%s" "$request" | openssl dgst -sha256 | awk '{print $2}')

  local cache_dir
  cache_dir=$(find_cache_dir)
  mkdir -p "$cache_dir"
  cache_match=$(find "$cache_dir" -name "${fingerprint}:${request_hash}:*" -print -quit)

  local response_json
  if [ -n "$cache_match" ]; then
    printf "🎯" >&2
    response_json=$(cat "$cache_match")
  else
    printf "💭" >&2
    response_json=$(curl -s -X POST "$endpoint" -H "Authorization: Bearer $api_key" -H "Content-Type: application/json" -d "$request")

      # DEBUG After curl
      if [ -z "$response_json" ]; then
        echo "DEBUG: infer: response_json is empty" >&2
        echo "[]"
        return 1
      fi


    # Check if the server response is an object before indexing keys like "id"
    local response_id
    if jq -e 'type == "object"' <<< "$response_json" >/dev/null 2>&1; then
      response_id=$(printf "%s" "$response_json" | jq -r '.id // "unknown_id"')
    else
      response_id="unknown_id"
    fi
    
    printf "%s" "$response_json" > "${cache_dir}/${fingerprint}:${request_hash}:${response_id}.json"
  fi

  # --- HARDENED TYPE-AGNOSTIC EXTRACTION LAYER ---
  local assistant_msg_block
  assistant_msg_block=$(jq -c '
    if type == "object" then
      if .choices and (.choices | type == "array") and (length > 0) then
        .choices[0].message
      elif .role and .content then
        .
      else
        {"role": "assistant", "content": (.content // .message // "")}
      fi
    elif type == "array" and (length > 0) then
      if .[-1].role == "assistant" then .[-1] else {"role": "assistant", "content": .[-1]} end
    else
      {"role": "assistant", "content": (type | tostring)}
    fi' <<< "$response_json" 2>/dev/null)

  if [ -z "$assistant_msg_block" ] || [ "$assistant_msg_block" = "null" ]; then
    local fallback_content
    fallback_content=$(jq -r '.choices[0].message.content // .content // empty' <<< "$response_json" 2>/dev/null)
    if [ -z "$fallback_content" ] && ! jq -e '.' <<< "$response_json" >/dev/null 2>&1; then
      fallback_content="$response_json"
    fi
    assistant_msg_block=$(jq -n -c --arg c "$fallback_content" '{"role": "assistant", "content": $c}')
  fi

  jq -c --argjson history "$clean_stdin" --argjson msg "$assistant_msg_block" '$history + [$msg]' <<< "{}"
}
