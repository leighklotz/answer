#!/usr/bin/env -S bash

SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE}")")"
source "${SCRIPT_DIR}/../env.sh"
source "${SCRIPT_DIR}/../logging.sh"

# Require stdin so interactive invocation fails fast instead of blocking.
if [ -t 0 ]; then
    log_and_exit 1 "No stdin detected. Requires inference response."
fi

printf "%s\n" "$SCROLL_ICON" >&2

jq -r --arg stats_icon "$STATS_ICON" '
    "***\n### \($stats_icon) Statistics\n" +
    "\n**Model Information**\n" +
    "* **Model ID:** \(.model)\n" +
    "* **Completion ID:** \(.id)\n" +
    "* **Finish Reason:** \(.choices[0].finish_reason // "N/A")\n" +
    (if .system_fingerprint then "* **System Fingerprint:** \(.system_fingerprint)\n" else "" end) +
    "\n**Token Usage**\n" +
    "* **Prompt Tokens:** \(.usage.prompt_tokens // 0) (\(.usage.prompt_tokens_details.cached_tokens // 0) cached, \(.usage.prompt_tokens_details.cache_write_tokens // 0) cache write)\n" +
    "* **Completion Tokens:** \(.usage.completion_tokens // 0) (\(.usage.completion_tokens_details.reasoning_tokens // 0) reasoning)\n" +
    "* **Total Tokens:** \(.usage.total_tokens // 0)\n" +
    (if .usage.cost then
        "\n**Cost**\n" +
        "* **Total Cost:** $\(.usage.cost)\n" +
        "* **BYOK:** \(.usage.is_byok // false)\n" +
        "* **Upstream Inference Cost:** $\(.usage.cost_details.upstream_inference_cost // .usage.cost)\n" +
        "* **Upstream Prompt Cost:** $\(.usage.cost_details.upstream_inference_prompt_cost // 0)\n" +
        "* **Upstream Completions Cost:** $\(.usage.cost_details.upstream_inference_completions_cost // 0)\n"
    else "" end) +
    (if ((.usage.prompt_tokens_details.audio_tokens // 0) +
         (.usage.prompt_tokens_details.video_tokens // 0) +
         (.usage.completion_tokens_details.audio_tokens // 0) +
         (.usage.completion_tokens_details.image_tokens // 0)) > 0 then
        "\n**Multimodal Token Details**\n" +
        "* **Prompt Audio Tokens:** \(.usage.prompt_tokens_details.audio_tokens // 0)\n" +
        "* **Prompt Video Tokens:** \(.usage.prompt_tokens_details.video_tokens // 0)\n" +
        "* **Completion Audio Tokens:** \(.usage.completion_tokens_details.audio_tokens // 0)\n" +
        "* **Completion Image Tokens:** \(.usage.completion_tokens_details.image_tokens // 0)\n"
    else "" end) +
    (if .timings then
        "\n**Performance & Latency**\n" +
        "| Metric | Time (ms) | Speed (tok/s) |\n" +
        "| :--- | :--- | :--- |\n" +
        "| **Prompt Processing** | \(.timings.prompt_ms // 0) ms | \(.timings.prompt_per_second // 0) tok/s |\n" +
        "| **Generation (Predicted)** | \(.timings.predicted_ms // 0) ms | \(.timings.predicted_per_second // 0) tok/s |"
    else "" end)
'
