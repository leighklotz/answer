#!/usr/bin/env -S bash -e

SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE}")")"
source "${SCRIPT_DIR}/../env.sh"
source "${SCRIPT_DIR}/../logging.sh"
source "${SCRIPT_DIR}/../functions.sh"

# Fetch all loaded models into a variable (each model is one line of JSON)
MODEL_DATA=$(curl -fsS "${VIA_API_CHAT_BASE}/models" | jq -c ".data[] | select(.status.value == \"loaded\")")

if [[ -n "$MODEL_DATA" ]]; then
    # Wrap everything in a group to pipe the whole stream into 'column' at once
    {
        # Print the Header Row first (using tabs)
        printf "Name\tSize(GB)\tReasoning\tContext\n"

        # Loop through each model object line by line
        while read -r row; do
            [ -z "$row" ] && continue

            NAME=$(echo "$row" | jq -r '.id')
            
            # Extract Size from .meta.size (convert bytes to GB via awk)
            SIZE_BYTES=$(echo "$row" | jq -r '.meta.size // 0')
            if [[ -z "$SIZE_BYTES" || "$SIZE_BYTES" == "null" ]]; then
                SIZE_GB="0.00"
            else
                SIZE_GB=$(awk "BEGIN {printf \"%.2f\", $SIZE_BYTES/1073741824}")
            fi

            # Check if reasoning is enabled via a single robust JQ call
            if echo "$row" | jq -e 'any(.status.args[]; . == "--reasoning") or (.preset // "" | contains("reasoning = on"))' >/dev/null 2>&1; then
                REASONING="Yes"
            else
                REASONING="No"
            fi

            # Context length per model - llama.cpp reports it in meta.n_ctx
            CTX=$(echo "$row" | jq -r '.meta.n_ctx // .n_ctx // empty')
            if [[ -z "$CTX" || "$CTX" == "null" ]]; then
                CTX="?"
            fi

            # Output current model row: Name [TAB] Size_GB [TAB] Reasoning [TAB] Context
            printf "%s\t%s\t%s\t%s\n" "$NAME" "$SIZE_GB" "$REASONING" "$CTX"

        done <<< "$(echo "$MODEL_DATA")"
    } | column -t  # <--- This handles the alignment for everything above it
else
    echo "Error: No loaded models found or metadata unavailable." >&2
    exit 1
fi
