#!/usr/bin/env -S bash

SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE}")")"
source "${SCRIPT_DIR}/../env.sh"
source "${SCRIPT_DIR}/../logging.sh"
source "${SCRIPT_DIR}/../functions.sh"

# 1. If no arguments are provided, behave exactly as before (return the single primary model)
if [[ $# -eq 0 ]]; then
    _get_model_name
    exit 0
fi

# Handle load/unload commands specifically to allow 'hx load <mname>' and 'hx unload' via dispatcher
case "$1" in
  load)
    shift
    _load_model "$@"
    exit 0
    ;;
  unload)
    shift
    if [[ -z "$1" ]]; then
      # If no model name provided, try to find the current one and unload it.
      m=$(_get_model_name)
      [[ -n "$m" ]] && _unload_model "$m" || echo "No models currently loaded." >&2
    else
      _unload_model "$1"
    fi
    exit 0
    ;;
esac

# 2. Fetch all currently loaded models from the API
ALL_LOADED=$(curl -fsS "${VIA_API_CHAT_BASE}/models" | jq -rc '.data[] | select(.status.value == "loaded") | .id')

if [[ -z "$ALL_LOADED" ]]; then
    echo "Error: No models currently loaded." >&2
    exit 1
fi

# 3. Filter the list of names based on all provided substrings (AND logic)
MATCHES=$(echo "$ALL_LOADED" | while read -r model; do
    keep=true
    for pattern in "$@"; do
        if [[ ! "$model" == *"$pattern"* ]]; then
            keep=false
            break
        fi
    done
    [[ "$keep" == true ]] && echo "$model"
done)

# 4. Output results or error message
if [[ -n "$MATCHES" ]]; then
    echo "$MATCHES" | sed '/^$/d' # Ensure no empty lines are returned if there were blanks in the list
else
    printf "* No models matching: %s\n" "$*" >&2
    exit 1
fi
