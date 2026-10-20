#!/usr/bin/env -S bash

set -euo pipefail

SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE}")")"
source "${SCRIPT_DIR}/../env.sh"
source "${SCRIPT_DIR}/../logging.sh"

if [ -t 0 ]; then
    log_and_exit 1 "No stdin detected. Requires inference response."
fi

json="$(cat)"
[[ -n "$json" ]] || { log_and_exit 1 "No stdin detected. Requires inference response."; }

shape="$(jq -r 'type' <<<"$json" 2>/dev/null)" || { log_and_exit 1 "Invalid JSON on stdin."; }

model_id=""
completion_id=""
finish_reason=""
prompt_tokens=0
cached_tokens=0
total_tokens=0
prompt_ms=0
prompt_per_second=0
predicted_ms=0
predicted_per_second=0
is_request=false
tools_json=""

case "$shape" in
  object)
    model_id="$(jq -r '.model // empty' <<<"$json")"
    completion_id="$(jq -r '.id // empty' <<<"$json")"
    finish_reason="$(jq -r '.choices[0].finish_reason // .finish_reason // empty' <<<"$json")"
    prompt_tokens="$(jq -r '.usage.prompt_tokens // 0' <<<"$json")"
    cached_tokens="$(jq -r '.usage.prompt_tokens_details.cached_tokens // 0' <<<"$json")"
    total_tokens="$(jq -r '.usage.total_tokens // 0' <<<"$json")"
    prompt_ms="$(jq -r '.timings.prompt_ms // 0' <<<"$json")"
    prompt_per_second="$(jq -r '.timings.prompt_per_second // 0' <<<"$json")"
    predicted_ms="$(jq -r '.timings.predicted_ms // 0' <<<"$json")"
    predicted_per_second="$(jq -r '.timings.predicted_per_second // 0' <<<"$json")"

    # Request-only: has .messages but no .choices[0].message (no inference captured)
    has_choices="$(jq -r '
      if (.choices? // null) and ((.choices | length) > 0) and (.choices[0].message? // null)
      then "yes" else "no" end
    ' <<<"$json")"

    if [[ "$has_choices" == "no" ]]; then
      is_request=true
      tools_json="$(jq -c '.tools // empty' <<<"$json")"
      json="$(jq -c '.messages // []' <<<"$json")"
    else
      json="$(jq -c '
        [ .choices[0].message
          | { role: "assistant",
              content: (.content // ""),
              reasoning_content: (.reasoning_content // ""),
              tool_calls: (.tool_calls // null) } ]
      ' <<<"$json")"
    fi
    ;;
  array)
    json="$(jq -c '.' <<<"$json")"
    ;;
  *)
    log_and_exit 1 "Unexpected top-level type: $shape" ;;
esac

printf "%s\n" "$SCROLL_ICON" >&2
echo ""

if [[ "$is_request" == true ]]; then
  echo "### 📥 Request Payload"
else
  echo "### 💬 Conversation"
fi
echo ""

jq -r '
  .[] |
  if .role == "assistant" then
    "  **Assistant**" +
    (if (.content // "") != "" then "\n  \(.content)" else "" end) +
    (if ((.tool_calls? // []) | length) > 0 then
      "\n\n  **Tool Calls**" +
      ([ (.tool_calls // [])[] |
          "  - `\((.function? // {}).name // "?")`(\((.function? // {}).arguments // "{}"))"
        ] | join("\n"))
    else "" end)
  elif .role == "tool" then
    "  **Tool** \(.tool_call_id // "—"):\n  \(.content // "")"
  else
    "**\(.role):** \(.content // "")\n"
  end
' <<<"$json" || echo "  *(empty)*"

echo ""

# Tools listing (request-only)
if [[ "$is_request" == true && -n "$tools_json" && "$tools_json" != "null" ]]; then
  tool_count="$(jq 'length' <<<"$tools_json")"
  echo "### 🔧 Available Tools ($tool_count)"
  jq -r '.[] | "  - `\(.function.name)` — \(.function.description | split("\n")[0])"' <<<"$tools_json"
  echo ""
fi

# Assistant sections
if [[ "$is_request" == true ]]; then
  echo "### 🧠 **Assistant Reasoning**"
  echo "  _pending — no inference captured_"
  echo ""
  echo "### 💭 **Assistant Response**"
  echo "  _pending — no inference captured_"
  echo ""
else
  last_reasoning="$(jq -r '[.[] | select(.role=="assistant")] | last | (.reasoning_content // .reasoning // empty)' <<<"$json" 2>/dev/null || true)"
  last_content="$(jq -r '[.[] | select(.role=="assistant")] | last | (.content // empty)' <<<"$json" 2>/dev/null || true)"
  last_tool_calls="$(jq -c '[.[] | select(.role=="assistant")] | last | (.tool_calls | if . == null or . == [] then empty else . end)' <<<"$json" 2>/dev/null || true)"

  echo "### 🧠 **Assistant Reasoning**"
  if [[ -n "$last_reasoning" && "$last_reasoning" != "null" ]]; then
    echo "$last_reasoning"
  else
    echo "N/A"
  fi
  echo ""
  echo "### 💭 **Assistant Response**"
  if [[ -n "$last_content" && "$last_content" != "null" ]]; then
    echo "$last_content"
  else
    echo "N/A"
  fi
  echo ""

  if [[ -n "$last_tool_calls" ]]; then
    echo "### 🔧 **Tool Calls**"
    jq -r '.[] | "  - `\(.function.name)`(\(.function.arguments))"' <<<"$last_tool_calls"
    echo ""
  fi
fi

echo "***"
echo ""
echo "### 📊 Statistics"

if [[ "$is_request" == true ]]; then
  msg_count="$(jq 'length' <<<"$json")"
  echo "**Request Payload**"
  echo "* **Model:** ${model_id:-N/A}"
  echo "* **Messages:** ${msg_count} turn(s) (system + user, no assistant)"
  echo "* **Completion ID:** _(none — not yet inferred)_"
else
  echo "**Model Information**"
  echo "* **Model ID:** ${model_id:-N/A}"
  echo "* **Completion ID:** ${completion_id:-null}"
  echo "* **Finish Reason:** ${finish_reason:-N/A}"
  echo ""
  echo "**Token Usage**"
  echo "* **Prompt Tokens:** ${prompt_tokens} (${cached_tokens} cached)"
  echo "* **Total Tokens:** ${total_tokens}"
  echo ""
  echo "**Performance & Latency**"
  echo "| Metric | Time (ms) | Speed (tok/s) |"
  echo "| :--- | :--- | :--- |"
  echo "| **Prompt Processing** | ${prompt_ms} ms | ${prompt_per_second} tok/s |"
  echo "| **Generation (Predicted)** | ${predicted_ms} ms | ${predicted_per_second} tok/s |"
fi
