#!/usr/bin/env -S bash

SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE}")")"
source "${SCRIPT_DIR}/../env.sh"
source "${SCRIPT_DIR}/../logging.sh"
source "${SCRIPT_DIR}/../functions.sh}"

# 1. Get the name of the loaded model using existing logic
NAME=$(_get_model_name)

# 2. Fetch full metadata for that specific loaded model to get size and reasoning capability
MODEL_DATA=$(curl -fsS "${VIA_API_CHAT_BASE}/models" | jq -c ".data[] | select(.id == \"$NAME\")")

if [[ -n "$MODEL_DATA" ]]; then
    # Extract Size from .meta.size (convert bytes to GB via awk)
    SIZE_BYTES=$(echo "$MODEL_DATA" | jq -r '.meta.size // 0')
    # Outputting as a pure number for clean TSV data processing
    SIZE_GB=$(awk "BEGIN {printf \"%.2f\", $SIZE_BYTES/1073741824}")

    # Check if reasoning is enabled in the status arguments or preset string
    REASONING="No"
    if echo "$MODEL_DATA" | jq -e '.status.args[] == "--reasoning"' >/dev/null 2>&1 || \
       echo "$MODEL_DATA" | jq -r '.preset // ""' | grep -q "reasoning = on"; then
        REASONING="Yes"
    fi

    # Output as TSV: Name [TAB] Size_GB [TAB] Reasoning
    printf "%s\t%s\t%s\n" "$NAME" "$SIZE_GB" "$REASONING"
else
    # Print to stderr so it doesn't corrupt a redirected TSV file, 
    # or output N/A if you want the row present in a loop.
    echo "Error: Model $NAME metadata unavailable" >&2
fi
