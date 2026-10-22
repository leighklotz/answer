#!/usr/bin/env -S bash
#
# decide — structured decision gate: schema + state in, typed JSON out.
#
#   <conversation-json | raw-text> | decide [--tee|--json] [--model M] <schema.json>
#
# It is a single stateless POST to /v1/systemone (Jev Structured Decision
# API). Every question is evaluated in parallel and in isolation against the
# same state — no text generation, nothing to parse.
#
# Stdin is auto-detected (see doc/commands/decide.md):
#   - magic-header conversation JSON  -> last assistant message is the state
#   - plain JSON conversation array   -> last assistant message is the state
#   - anything else                   -> the entire stream is the state
#
# Output modes: --json (answers object on stdout), --tee (summary on stderr,
# full response on stdout), default: full response JSON on stdout.

SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
source "${SCRIPT_DIR}/env.sh"
source "${SCRIPT_DIR}/logging.sh"
source "${SCRIPT_DIR}/functions.sh"

set -o pipefail

usage() {
  cat >&2 <<'USAGE'
Usage: <conversation-json | raw-text> | decide [OPTIONS] <schema.json>

Options:
  -s, --schema FILE   Schema file (alternative to the positional argument)
  --model STRING      Decision model (default: laya-q8_0)
  -j, --json          Emit only the answers object on stdout (data mode)
  -t, --tee           Summary on stderr, full JSON response on stdout
  -h, --help          This help

Input (auto-detected): pipeline JSON history (magic header), a bare JSON
conversation array, or raw text — raw text is used verbatim as the state.

Exit codes: 0 success, 1 usage/schema/API failure, 2 interrupted.
USAGE
  exit 1
}

DECISION_MODEL="${HX_DECIDE_MODEL:-laya-q8_0}"
JSON_MODE=''
TEE_MODE=''
SCHEMA_FILE=''

# --- ARGUMENT PARSING (same shape as answer.sh) ---
while [[ $# -gt 0 ]]; do
  case "$1" in
    -s|--schema)
      [[ -n ${2:-} ]] || usage
      SCHEMA_FILE="$2"; shift 2
      ;;
    --model)
      [[ -n ${2:-} ]] || usage
      DECISION_MODEL="$2"; shift 2
      ;;
    -j|--json)
      JSON_MODE=1; shift
      ;;
    -t|--tee)
      TEE_MODE=1; shift
      ;;
    -h|--help)
      usage
      ;;
    --*)
      log_error "decide: unknown option '$1'"
      usage
      ;;
    *)
      break # first positional: the schema file
      ;;
  esac
done

if [[ -z $SCHEMA_FILE && $# -gt 0 ]]; then
  SCHEMA_FILE="$1"
  shift
fi
if [[ $# -gt 0 ]]; then
  log_error "decide: unexpected extra arguments: $*"
  usage
fi
if [[ -z $SCHEMA_FILE ]]; then
  log_error "decide: a schema file is required."
  usage
fi

[[ -f $SCHEMA_FILE ]] || log_and_exit 1 "decide: schema file not found: '$SCHEMA_FILE'"
jq -e '.questions | type == "object" and length > 0' "$SCHEMA_FILE" >/dev/null 2>&1 \
  || log_and_exit 1 "decide: schema has no '.questions' object: '$SCHEMA_FILE'"

# --- STDIN VALIDATION & STATE EXTRACTION ---
if [ -t 0 ]; then
  log_and_exit 1 "No stdin detected. Pipe a conversation (from ask) or raw text into decide."
fi

_ensure_workspace
_mktemp_reg 'decide.XXXXXX.json' && raw_in="$MKTEMP_REG"
_mktemp_reg 'decide_state.XXXXXX.txt' && state_file="$MKTEMP_REG"
_mktemp_reg 'decide_request.XXXXXX.json' && request_file="$MKTEMP_REG"

cat > "$raw_in"

# Strip the magic header if present.
if [[ "$(head -n 1 "$raw_in")" == "${PIPELINE_MAGIC_HEADER}" ]]; then
  tail -n +2 "$raw_in" > "${raw_in}.body" && mv "${raw_in}.body" "$raw_in"
fi

is_json_conv=false
last_role=$(jq -r 'if type == "array" and length > 0 then last.role else empty end' "$raw_in" 2>/dev/null)
if [[ -n $last_role ]]; then
  is_json_conv=true
fi

if $is_json_conv; then
  if [[ $last_role == "assistant" ]]; then
    # Case 2: last message is an assistant response — use it directly.
    log_info "decide: using last assistant message as state."
    if ! jq -r 'last | .content | select(type == "string" and length > 0)' "$raw_in" > "$state_file" 2>/dev/null ||
       ! grep -q '[^[:space:]]' "$state_file"; then
      log_and_exit 1 "decide: last assistant message has no string content."
    fi
  else
    # Case 1: last message is NOT an assistant (e.g. user) — auto-resolve via answer.
    log_info "decide: no trailing assistant message; resolving via answer."
    if ! jq -c . "$raw_in" | answer -m > "$state_file" 2>/dev/null ||
       ! grep -q '[^[:space:]]' "$state_file"; then
      log_and_exit 1 "decide: answer failed to resolve conversation history."
    fi
  fi
else
  # Case 3: not a JSON conversation — use the entire stream verbatim as state.
  log_info "decide: stdin is raw text; using verbatim."
  mv "$raw_in" "$state_file"
fi

if ! grep -q '[^[:space:]]' "$state_file"; then
  log_and_exit 1 "decide: state is empty or whitespace-only — nothing to decide on."
fi

# --- REQUEST CONSTRUCTION (jq, no string interpolation) ---
jq -n \
  --arg model "$DECISION_MODEL" \
  --rawfile state "$state_file" \
  --slurpfile schema "$SCHEMA_FILE" \
  '{
    model: $model,
    state: ($state | sub("\\n+$"; "") | sub("^\\n+"; "")),
    questions: $schema[0].questions
  }' > "$request_file" \
  || log_and_exit 1 "decide: failed to build the request body."

# --- API CALL ---
api_key="${OPENAI_API_KEY:-${AIHUBMIX_API_KEY:-}}"
endpoint="${HX_DECIDE_ENDPOINT:-${VIA_API_CHAT_BASE}/v1/systemone}"

log_info "decide: model=$DECISION_MODEL questions=$(jq '.questions | length' "$SCHEMA_FILE") state_len=$(wc -c < "$state_file")"
emit_icon_tooltip "$DECISION_ICON" "$endpoint"

response_json=$(_infer_request_post "$endpoint" "$request_file" "$api_key") || {
    echo "# request file" >&2
    cat $request_file >&2
  log_and_exit 1 "decide: API request failed (endpoint=$endpoint)"
}

# echo "# request file $request_file" >&2
# cat -n "$request_file" >&2
# _infer_request_post "$endpoint" "$request_file" "$api_key"
# exit 34

if ! jq -e . >/dev/null 2>&1 <<< "$response_json"; then
  log_and_exit 1 "decide: API response is not valid JSON: ${response_json:0:200}"
fi
if jq -e '.error != null' >/dev/null 2>&1 <<< "$response_json"; then
  log_and_exit 1 "decide: API returned an error: $(jq -c '.error' <<< "$response_json")"
fi

answers=$(jq -c '.answers // empty' <<< "$response_json")
if [[ -z $answers ]]; then
  log_and_exit 1 "decide: API response has no answers object: $(jq -c . <<< "$response_json" | head -c 200)"
fi

# --- OUTPUT ---
# stdout: the decision channel; stderr: chatter / human summary.
if [[ $TEE_MODE -eq 1 ]]; then
  # stderr: one-line-per-question human summary; stdout: magic-header-prefixed
  # full response JSON so any downstream Hallux command can resume the pipeline.
  emit_icon_tooltip "${TEE_ICON}" "decision"
  jq -r '.answers | to_entries[] | "\(.key): " +
    (if .value.type == "noul" then "noul=\(.value.noul)"
     elif .value.type == "choice" then "choice=\(.value.choice) (conf=\(.value.confidence))"
     elif .value.type == "score" then "score=\(.value.score) (conf=\(.value.confidence))"
     else (.value | tostring) end)' <<< "$response_json" >&2
  printf "%s\n%s\n" "${PIPELINE_MAGIC_HEADER}" "$(jq -c . <<< "$response_json")"
elif [[ $JSON_MODE -eq 1 ]]; then
  # stdout: raw answers object only — pipe straight into jq and branch.
  jq . <<< "$answers"
else
  # stdout: full response, pretty-printed.
  jq . <<< "$response_json"
fi

exit 0
