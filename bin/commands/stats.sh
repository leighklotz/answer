#!/usr/bin/env -S bash

SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE}")")"
source "${SCRIPT_DIR}/../env.sh"
source "${SCRIPT_DIR}/../logging.sh"

# Require stdin so interactive invocation fails fast instead of blocking.
if [ -t 0 ]; then
    log_and_exit 1 "No stdin detected. Requires inference response."
fi

printf "%s\n" "$SCROLL_ICON" >&2

jq -r --arg stats_icon "$STATS_ICON" '"***
### \($stats_icon) Statistics
**Model Information**
* **Model ID:** \(.model)
* **Completion ID:** \(.id)
* **Finish Reason:** \(.choices[0].finish_reason // "N/A")

**Token Usage**
* **Prompt Tokens:** \(.usage.prompt_tokens // 0) (\(.usage.prompt_tokens_details.cached_tokens // 0) cached)
* **Total Tokens:** \(.usage.total_tokens // 0)

**Performance & Latency**
| Metric | Time (ms) | Speed (tok/s) |
| :--- | :--- | :--- |
| **Prompt Processing** | \(.timings.prompt_ms // 0) ms | \(.timings.prompt_per_second // 0) tok/s |
| **Generation (Predicted)** | \(.timings.predicted_ms // 0) ms | \(.timings.predicted_per_second // 0) tok/s |"
'
