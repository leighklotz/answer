#!/usr/bin/env -S bash
#
# decide — structured decision gate: schema + state in, typed JSON out.
#
#   <conversation-json | raw-text> | decide [--tee|--json] [--model M] <schema.json>
#   <conversation-json | raw-text> | decide [--tee|--json] [--model M] "<intent>" select … option …
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
# The schema can be supplied as a file path or as an inline DSL (same
# grammar as `hx schema build`).
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
Usage:
  <state> | decide [OPTIONS] <schema_file>
  <state> | decide [OPTIONS] "<intent>" select <name> <type> <instr> [option …] …

Options:
  -s, --schema FILE   Schema file (alternative to the positional argument)
  --model STRING      Decision model (default: laya-q8_0)
  -j, --json          Emit only the answers object on stdout (data mode)
  -t, --tee           Summary on stderr, full JSON response on stdout
  -h, --help          This help

Schema (one of):
  <schema_file>       Path to a JSON schema file.
  "<intent>" select … Inline DSL — same grammar as `hx schema build`.
                      The first positional is the intent (for logging),
                      subsequent tokens are the DSL stream.

Input (auto-detected): pipeline JSON history (magic header), a bare JSON
conversation array, or raw text — raw text is used verbatim as the state.

Exit codes: 0 success, 1 usage/schema/API failure, 2 interrupted.

Examples:
  echo "user ran sudo today" | decide schemas/risk.json
  echo "user ran sudo today" | decide --json "Security Gate" \
    select is_authorized noul "Does user have admin rights?" \
    select risk_level score "Potential threat level" option 'low|medium|high'
USAGE
  exit 1
}

DECISION_MODEL="${HX_DECISION_MODEL:-laya-q8_0}"
JSON_MODE=''
TEE_MODE=''
SCHEMA_FILE=''
_dsl_built=0

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
      break # first positional: schema file or DSL intent
      ;;
  esac
done

# --- SCHEMA SOURCE: file path OR inline DSL ---
# DSL mode: the first positional is the intent, the second is a DSL command
# word (select/option/options), and the rest are DSL tokens. We delegate to
# `hx schema build` (bin/commands/schema.sh) in a subprocess and capture its
# stdout (the finished schema JSON) into a temp file.
if [[ -z $SCHEMA_FILE && $# -ge 2 ]]; then
  case "$2" in
    select|option|options)
      _dsl_intent="$1"
      shift # consume the intent; remaining $@ are the DSL words
      log_info "decide: inline DSL schema (intent: ${_dsl_intent})"
      _mktemp_reg 'decide_schema.XXXXXX.json' \
        || log_and_exit 1 "decide: cannot create temp schema file"
      SCHEMA_FILE="$MKTEMP_REG"
      # stderr from schema.sh (progress, ✓ lines) passes through to the
      # terminal; stdout (the schema JSON) is captured.
      if ! "$SCRIPT_DIR/commands/schema.sh" build "$_dsl_intent" "$@" > "$SCHEMA_FILE"; then
        log_and_exit 1 "decide: inline schema build failed"
      fi
      if ! jq empty "$SCHEMA_FILE" 2>/dev/null; then
        log_and_exit 1 "decide: inline schema build produced invalid JSON"
      fi
      shift $#      # consume the DSL words from our positional params
      _dsl_built=1
      ;;
  esac
fi

# File mode (or fallback): the first positional is a schema file path.
if [[ -z $SCHEMA_FILE && $# -gt 0 ]]; then
  SCHEMA_FILE="$1"
  shift
fi
if [[ $# -gt 0 ]]; then
  log_error "decide: unexpected extra arguments: $*"
  usage
fi
if [[ -z $SCHEMA_FILE ]]; then
  log_error "decide: a schema file or inline DSL is required."
  usage
fi
# Existence check only for file-mode (DSL-mode file was just written+validated).
if (( ! _dsl_built )) && [[ ! -f $SCHEMA_FILE ]]; then
  log_error "decide: schema file not found: '$SCHEMA_FILE'"
  usage
fi

if [ -t 0 ]; then
  log_and_exit 1 "No stdin detected. Pipe a conversation (from ask) or raw text into decide."
fi

jq -e '.questions | type == "object" and length > 0' "$SCHEMA_FILE" >/dev/null 2>&1 \
  || log_and_exit 1 "decide: schema has no '.questions' object: '$SCHEMA_FILE'"

# --- STDIN VALIDATION & STATE EXTRACTION ---

_ensure_workspace
_mktemp_reg 'decide.XXXXXX.json' && raw_in="$MKTEMP_REG"
_mktemp_reg 'decide_state.XXXXXX.txt' && state_file="$MKTEMP_REG"
_mktemp_reg 'decide_request.XXXXXX.json' && request_file="$MKTEMP_REG"

cat > "$raw_in"

# Strip the magic header if present.
if [[ "$(head -n 1 "$raw_in")" == "${PIPELINE_MAGIC_HEADER}" ]]; then
  log_error "not supposed to happen: $raw_in"
  tail -n +2 "$raw_in" > "${raw_in}.body" && mv "${raw_in}.body" "$raw_in"
fi

is_json_conv=false
last_role=$(jq -r 'if type == "array" and length > 0 then last.role else empty end' "$raw_in" 2>/dev/null)
if [[ -n $last_role ]]; then
  is_json_conv=true
fi

if $is_json_conv; then
  if [[ $last_role == "assistant" ]]; then
    log_info "decide: using last assistant message as state."
    if ! jq -r 'last | .content | select(type == "string" and length > 0)' "$raw_in" > "$state_file" 2>/dev/null ||
       ! grep -q '[^[:space:]]' "$state_file"; then
      log_and_exit 1 "decide: last assistant message has no string content."
    fi
  else
    log_info "decide: no trailing assistant message; resolving via answer."
    if ! jq -c . "$raw_in" | answer -m > "$state_file" 2>/dev/null ||
       ! grep -q '[^[:space:]]' "$state_file"; then
      log_and_exit 1 "decide: answer failed to resolve conversation history."
    fi
  fi
else
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
api_key="${OPENAI_API_KEY:-}"
endpoint="${HX_DECIDE_ENDPOINT:-${VIA_API_CHAT_BASE}/v1/systemone}"

log_info "decide: model=$DECISION_MODEL questions=$(jq '.questions | length' "$SCHEMA_FILE") state_len=$(wc -c < "$state_file")"
emit_icon_tooltip "$DECISION_ICON" "$endpoint"

response_json=$(_infer_request_post "$endpoint" "$request_file" "$api_key") || {
    echo "# request file" >&2
    cat $request_file >&2
  log_and_exit 1 "decide: API request failed (endpoint=$endpoint)"
}

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
if [[ $TEE_MODE -eq 1 ]]; then
  emit_icon_tooltip "${TEE_ICON}" "decision"
  jq -r '.answers | to_entries[] | "\(.key): " +
    (if .value.type == "noul" then "noul=\(.value.noul)"
     elif .value.type == "choice" then "choice=\(.value.choice) (conf=\(.value.confidence))"
     elif .value.type == "score" then "score=\(.value.score) (conf=\(.value.confidence))"
     else (.value | tostring) end)' <<< "$response_json" >&2
  printf "%s\n%s\n" "${PIPELINE_MAGIC_HEADER}" "$(jq -c . <<< "$response_json")"
elif [[ $JSON_MODE -eq 1 ]]; then
  jq . <<< "$answers"
else
  jq . <<< "$response_json"
fi

exit 0
