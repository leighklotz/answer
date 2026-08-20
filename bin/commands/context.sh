#!/usr/bin/env -S bash

SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE}")")"
source "${SCRIPT_DIR}/hx-bootstrap.sh"
hx core
model=$(hx model)

echo "slot: tokens_used/context"
curl -fsS "${VIA_API_CHAT_BASE}/slots?model=$model" |
    jq -r '[.[] | select((.n_prompt_tokens // 0) > 0) | "\(.n_prompt_tokens)/\(.n_ctx)"] | join(" ")'
