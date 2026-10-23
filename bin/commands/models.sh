#!/usr/bin/env -S bash -e

SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE}")")"
source "${SCRIPT_DIR}/../env.sh"
source "${SCRIPT_DIR}/../logging.sh"
source "${SCRIPT_DIR}/../functions.sh"

CMD="$1"

# Determine mode: 'all' or default to 'loaded'
if [[ "$CMD" == "all" ]]; then
    MODE="all"
elif [[ "$CMD" == "loaded" ]] || [[ -z "$CMD" ]]; then
    MODE="loaded"
else
  echo "Usage: hx models [all|loaded]" >&2
  exit 1
fi

# Fetch model data based on mode
if [[ "$MODE" == "all" ]]; then
    MODEL_DATA=$(curl -fsS "${VIA_API_CHAT_BASE}/models" | jq -c ".data[]")
else
    MODEL_DATA=$(curl -fsS "${VIA_API_CHAT_BASE}/models" | jq -c ".data[] | select(.status.value == \"loaded\")")
fi

if [[ -n "$MODEL_DATA" ]]; then
    {
        printf "Name\tSize(GB)\tReasoning\tContext\tInput\tOutput\n"

        while read -r row; do
            [ -z "$row" ] && continue

            NAME=$(echo "$row" | jq -r '.id')

            SIZE_BYTES=$(echo "$row" | jq -r '.meta.size // 0')
            if [[ -z "$SIZE_BYTES" || "$SIZE_BYTES" == "null" ]]; then
                SIZE_GB="-"
            else
                SIZE_GB=$(awk "BEGIN {printf \"%.2f\", $SIZE_BYTES/1073741824}")
            fi

            if echo "$row" | jq -e 'any(.status.args[]; . == "--reasoning")' >/dev/null 2>&1; then
                REASONING="Yes"
            else
                REASONING="No"
            fi

            CTX=$(echo "$row" | jq -r '.context_length // empty')
            if [[ -z "$CTX" || "$CTX" == "null" ]]; then
                CTX="-"
            fi

            INPUT=$(echo "$row" | jq -r '.architecture.input_modalities | join(":")')
            OUTPUT=$(echo "$row" | jq -r '.architecture.output_modalities | join(":")')

            printf "%s\t%s\t%s\t%s\t%s\t%s\n" "$NAME" "$SIZE_GB" "$REASONING" "$CTX" "$INPUT" "$OUTPUT"

        done <<< "$(echo "$MODEL_DATA")"
    } | column -t -s$'\t'
else
    if [[ "$MODE" == "all" ]]; then
       echo "No models available." >&2
    else
       echo "Error: No loaded models found or metadata unavailable." >&2
    fi
    exit 1
fi
