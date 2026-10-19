#!/usr/bin/env -S bash
#
# hx schema — build a decide schema from a small stream DSL.
#
#   hx schema build <intent> [dsl words...]
#
# The DSL words follow the intent. There is no `finish` command: when the
# words run out the accumulated schema is validated and written to stdout,
# so it can be redirected straight into a file:
#
#   hx schema build "Gate" select ok noul "ok to proceed?" > gate.json
#
# Grammar: everything is positional and REQUIRED — nothing is inferred:
#
#   select <name> <type> <instructions...>
#     <name>          unique field name; declaring it twice is an error
#     <type>          exactly one of: choice | score | noul
#     <instructions>  ALL remaining words, joined with spaces; REQUIRED
#                     even when empty — pass an explicit ""
#
#   option <args...>   (alias: options) — must follow its select; semantics
#                      follow the field's declared type:
#     choice: option <key> [<description...>] — one entry per command;
#             entries accumulate; duplicate keys are an error; the
#             description is all remaining words joined, and may be empty
#     score:  option <level...> — level labels in order; a single token is
#             split on '|'; entries accumulate in order
#     noul:   rejected — the probability is decided at runtime
#
# At the end of the words the accumulated schema is validated and
# written to stdout. If any command errored, the emit refuses to write and
# the exit is non-zero.
#
# Argument-form caveat: a token that is exactly select/option/options
# starts a new command — instruction or description text must not begin
# with one of those words. Because a quoted value is a single token and
# never splits, leading command words are rejected where the text is
# assembled (select instructions and choice descriptions).
#
# Set HALLUX_SCHEMA_DEBUG=1 to echo the parsed commands (positional args
# and flags) while building.

# --- SETUP & SOURCE (Standard Hallux Pattern) ---
SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE}")")"
source "${SCRIPT_DIR}/../env.sh"
source "${SCRIPT_DIR}/../logging.sh"
source "${SCRIPT_DIR}/../functions.sh"

set -o pipefail

# --- FIELD TYPES (the closed type set from doc/commands/schema.md) ---
TYPE_CHOICE="choice"
TYPE_SCORE="score"
TYPE_NOUL="noul"

usage() {
  cat >&2 <<'USAGE'
Usage: hx schema build <intent> [dsl words...]

Builds a decision schema consumed by `decide`. The DSL words follow the
intent; there is no `finish` command — when the words run out the finished
schema is written to stdout, so it can be redirected straight into a file:

    hx schema build "Gate" select ok noul "ok to proceed?" > gate.json

DSL commands (positional; the argument form splits at the command words):

  select <name> <type> <instructions...>
      <name>          unique field name (required)
      <type>          exactly one of: choice | score | noul  (required)
      <instructions>  all remaining words joined with spaces (required);
                      pass an explicit "" when a field needs none

  option <args...>    (alias: options) — must follow its select
      choice: option <key> [<description...>]
              one entry per command; entries accumulate; duplicate keys
              error; the description may be empty
      score:  option <level...>
              level labels in order; a single token splits on '|';
              entries accumulate in order
      noul:   rejected — the probability is decided at runtime

At the end of the words the accumulated schema is validated and written
to stdout. If any command errored, nothing is written and the exit is
non-zero.

Caveat: a token that is exactly select/option/options starts a new
command — instruction/description text must not begin with one of those
words; text that does begin with a command word is rejected loudly.

Set HALLUX_SCHEMA_DEBUG=1 to echo the parsed commands while building.
USAGE
  exit 1
}

_ensure_workspace || exit 1

# --- STATE MANAGEMENT ---
SCHEMA_TMP="$HALLUX_TMP_DIR/current_schema.json"
SCHEMA_TMP_NEW="${SCHEMA_TMP}.tmp"

# Always start from a clean slate: a run that died mid-build must not leak
# the previous session's half-built schema into this one.
mkdir -p "$HALLUX_TMP_DIR" 2>/dev/null || true
if ! printf '{"questions": {}}\n' > "$SCHEMA_TMP"; then
  log_error "cannot initialise schema state file '$SCHEMA_TMP'"
  exit 1
fi
trap 'rm -f "$SCHEMA_TMP" "$SCHEMA_TMP_NEW"' EXIT

# --- PARSE STATE (globals shared by the helpers below) ---
declare -a _SCHEMA_TOKENS=()
declare -a _SCHEMA_POSITIONAL=()
declare -A _SCHEMA_FLAGS=()
current_name=""
schema_errors=0
commands_seen=0

# Record an error (counted, so the end-of-input emit can refuse) and fail.
_schema_fail() {
  log_error "$*"
  schema_errors=$((schema_errors + 1))
  return 1
}

# ── Tokenising ────────────────────────────────────────────────────────

# _SCHEMA_TOKENS[0] is the command word; the rest becomes positional
# arguments plus "--flag value" / "--flag=value" pairs. Flags are parsed
# structurally only so they can be REJECTED by name — the grammar is
# entirely positional.
_schema_parse_tokens() {
  _SCHEMA_POSITIONAL=()
  _SCHEMA_FLAGS=()
  local t i=1 n=${#_SCHEMA_TOKENS[@]}
  while (( i < n )); do
    t=${_SCHEMA_TOKENS[i]}
    if [[ $t == --* ]]; then
      if [[ $t == *=* ]]; then
        _SCHEMA_FLAGS[${t%%=*}]=${t#*=}
        i=$((i + 1))
      elif (( i + 1 < n )) && [[ ${_SCHEMA_TOKENS[i + 1]} != --* ]]; then
        _SCHEMA_FLAGS[$t]=${_SCHEMA_TOKENS[i + 1]}
        i=$((i + 2))
      else
        _SCHEMA_FLAGS[$t]=""
        i=$((i + 1))
      fi
    else
      _SCHEMA_POSITIONAL+=("$t")
      i=$((i + 1))
    fi
  done
  return 0
}

# ── jq helpers ────────────────────────────────────────────────────────

# Run jq against the current schema and swap the file in only on success,
# so a failed transform never corrupts state.
_schema_apply_jq() {
  local prog=$1
  shift
  if ! jq "$prog" "$@" "$SCHEMA_TMP" > "$SCHEMA_TMP_NEW"; then
    rm -f "$SCHEMA_TMP_NEW"
    return 1
  fi
  mv "$SCHEMA_TMP_NEW" "$SCHEMA_TMP" || return 1
  return 0
}

# [{"level": ...}, ...] from the given items; a single item is split on '|'.
_schema_score_json() {
  local -a levels=()
  if (( $# == 1 )); then
    IFS='|' read -r -a levels <<< "$1"
  else
    levels=("$@")
  fi
  jq -n '
    [$ARGS.positional[] | gsub("^\\s+|\\s+$"; "")]
    | if length == 0 then error("no score levels given")
      elif any(.[]; length == 0) then error("score levels must not be empty")
      else map({level: .})
      end
  ' --args "${levels[@]}"
}

# Add ONE choice entry {"key": "desc"} to field $1; $2 = key, remaining
# words = the description (joined; may be empty). Entries accumulate; a
# duplicate key is a loud error rather than a silent overwrite.
_schema_apply_choice() {
  local field=$1 ckey=$2
  shift 2
  local desc=""
  if (( $# > 0 )); then
    desc="$*"
  fi

  # Caveat enforcement: description text must not BEGIN with a command
  # word — a quoted "option ..." is one argv token and never splits, so
  # it must be rejected here rather than stored verbatim.
  if [[ -n $desc ]]; then
    local dfirst="${desc%%[[:space:]]*}"
    case "$dfirst" in
      select|option|options)
        _schema_fail "option: description for field '$field' must not begin with the command word '$dfirst' — reword the description"
        return 1
        ;;
    esac
  fi

  local json
  if ! json=$(jq -n --arg k "$ckey" --arg d "$desc" '
      ($k | gsub("^\\s+|\\s+$"; "")) as $key
          | ($d | gsub("^\\s+|\\s+$"; "")) as $d
          | if ($key | length) == 0 then error("choice option key is empty")
            else {($key): $d}
            end
  '); then
    _schema_fail "option: invalid choice key for field '$field' (see jq error above)"
    return 1
  fi
  local dupkey
  if ! dupkey=$(jq -r --arg k "$field" --argjson c "$json" '
      (.questions[$k].criteria // {}) as $cur
      | ($c | keys[0]) as $nk
      | if ($cur | has($nk)) then $nk else empty end
  ' "$SCHEMA_TMP"); then
    _schema_fail "option: cannot check duplicate keys for field '$field'"
    return 1
  fi
  if [[ -n $dupkey ]]; then
    _schema_fail "option: choice key '$dupkey' already exists in field '$field'"
    return 1
  fi
  if ! _schema_apply_jq '
      .questions[$k].criteria = ((.questions[$k].criteria // {}) + $c)
      | .questions[$k].probabilities = (.questions[$k].probabilities // {})
    ' --arg k "$field" --argjson c "$json"; then
    _schema_fail "option: failed to store choice option for field '$field'"
    return 1
  fi
  return 0
}

# Append score levels to field $1; a single item is split on '|', multiple
# items are used as-is. Entries accumulate in order.
_schema_apply_score() {
  local field=$1
  shift
  local json
  if ! json=$(_schema_score_json "$@"); then
    _schema_fail "option: invalid score levels for field '$field' (see jq error above)"
    return 1
  fi
  if ! _schema_apply_jq '.questions[$k].criteria = ((.questions[$k].criteria // []) + $c)' \
       --arg k "$field" --argjson c "$json"; then
    _schema_fail "option: failed to store score levels for field '$field'"
    return 1
  fi
  return 0
}

# ── DSL commands ──────────────────────────────────────────────────────

_schema_cmd_select() {
  local -a pos=("${_SCHEMA_POSITIONAL[@]}")
  local name="${pos[0]:-}"

  if [[ -z $name ]]; then
    _schema_fail "select: a field name is required"
    return 1
  fi

  # Grammar: select <name> <type> <instructions...> — everything required,
  # nothing inferred. <type> must be exactly one of the closed type set;
  # all remaining words are the instructions text.
  if (( ${#pos[@]} < 2 )); then
    _schema_fail "select: a type is required for '$name' (one of: choice, score, noul)"
    return 1
  fi
  local type="${pos[1]}"
  case "$type" in
    "$TYPE_CHOICE"|"$TYPE_SCORE"|"$TYPE_NOUL") ;;
    *)
      _schema_fail "select: unknown type '$type' for '$name' — grammar: select <name> <type> <instructions...> (type: choice, score or noul)"
      return 1
      ;;
  esac

  # The DSL takes no flags — reject anything flag-shaped loudly, BEFORE the
  # instructions check, so legacy flag input gets the most useful message.
  local f
  for f in "${!_SCHEMA_FLAGS[@]}"; do
    _schema_fail "select: unknown flag '$f' — the DSL takes no flags; use: select <name> <type> <instructions...>"
    return 1
  done

  # Instructions are REQUIRED but may be an explicit empty string ("").
  # "Present" and "non-empty" are deliberately distinct.
  if (( ${#pos[@]} < 3 )); then
    _schema_fail "select: instructions are required for '$name' (pass an explicit \"\" if the field needs none)"
    return 1
  fi
  local -a text=("${pos[@]:2}")
  local instr="${text[*]}"

  # Caveat enforcement: instruction text must not BEGIN with a command
  # word — "select carefully" is one argv token and never splits, so it
  # must be rejected here instead of being silently absorbed. (Parameter
  # expansion rather than `read`: `read` reports non-zero at EOF, which a
  # `set -e` caller would treat as fatal on the empty-instructions path.)
  local first_word="${instr%%[[:space:]]*}"
  case "$first_word" in
    select|option|options)
      _schema_fail "select: instructions must not begin with the command word '$first_word' — reword the instructions"
      return 1
      ;;
  esac

  if jq -e --arg k "$name" '.questions | has($k)' "$SCHEMA_TMP" > /dev/null; then
    _schema_fail "select: field '$name' already exists"
    return 1
  fi
  if ! _schema_apply_jq '.questions[$k] = {"type": $t, "instructions": $i}' \
       --arg k "$name" --arg t "$type" --arg i "$instr"; then
    _schema_fail "select: failed to initialise field '$name'"
    return 1
  fi
  printf "  ${GREEN}✓${WOLFE} Field '%s' (type: %s) initialized.\n" "$name" "$type" >&2
  current_name="$name"
  return 0
}

_schema_cmd_option() {
  local f
  for f in "${!_SCHEMA_FLAGS[@]}"; do
    _schema_fail "option: unknown flag '$f' — the DSL takes no flags"
    return 1
  done
  if [[ -z $current_name ]]; then
    _schema_fail "option: no active field — 'option' must follow its 'select'"
    return 1
  fi
  if [[ -z ${_SCHEMA_POSITIONAL[0]:-} ]]; then
    _schema_fail "option: missing value"
    return 1
  fi
  local ftype
  if ! ftype=$(jq -r --arg k "$current_name" '.questions[$k].type // ""' "$SCHEMA_TMP"); then
    _schema_fail "option: cannot read the type of field '$current_name'"
    return 1
  fi
  local field="$current_name"

  # Route by the field's DECLARED type.
  case "$ftype" in
    "$TYPE_CHOICE")
      # option <key> [<description...>] — one entry; entries accumulate
      _schema_apply_choice "$field" "${_SCHEMA_POSITIONAL[0]}" "${_SCHEMA_POSITIONAL[@]:1}" || return 1
      ;;
    "$TYPE_SCORE")
      # option <level...> — a single token splits on '|'; levels accumulate
      _schema_apply_score "$field" "${_SCHEMA_POSITIONAL[@]}" || return 1
      ;;
    "$TYPE_NOUL")
      _schema_fail "option: fields of type 'noul' take no options (the probability is decided at runtime)"
      return 1
      ;;
    *)
      _schema_fail "option: field '$field' has unknown type '$ftype'"
      return 1
      ;;
  esac

  printf "  ${GREEN}✓${WOLFE} Options added to '%s'.\n" "$field" >&2
  return 0
}

# ── CORE ENGINE ───────────────────────────────────────────────────────

# Dispatch one parsed command (operates on _SCHEMA_TOKENS). The argument
# path is the only path, so the split-at-command-words behaviour and the
# error handling stay in one place.
_schema_dispatch() {
  local cmd="${_SCHEMA_TOKENS[0]:-}"
  _schema_parse_tokens
  commands_seen=$((commands_seen + 1))

  if [[ ${HALLUX_SCHEMA_DEBUG:-0} == 1 ]]; then
    printf "DBG cmd=%q positional=[%s] flags=[%s]\n" \
      "$cmd" "${_SCHEMA_POSITIONAL[*]}" "${!_SCHEMA_FLAGS[*]}" >&2
  fi

  case "$cmd" in
    select)         _schema_cmd_select || current_name="" ;;
    option|options) _schema_cmd_option || current_name="" ;;
    *)
      _schema_fail "Unknown command: '$cmd'. Available: select, option(s)."
      current_name=""
      ;;
  esac
  return 0
}

# Argument form: the DSL words come as argv after the intent. The shell has
# already done quote removal, so each argv word IS one DSL token — they must
# NOT be re-tokenised (that would shred multi-word values). Commands are
# recovered by splitting the stream at the command words; a quoted value is
# a single token and never splits.
_schema_run_args() {
  local -a group=()
  local t
  for t in "$@"; do
    if [[ $t == select || $t == option || $t == options ]] &&
       (( ${#group[@]} > 0 )); then
      printf "%s %s\n" "${USER_INPUT_ICON:-💬︎}" "${group[*]}" >&2
      _SCHEMA_TOKENS=("${group[@]}")
      group=()
      _schema_dispatch
    fi
    group+=("$t")
  done
  if (( ${#group[@]} > 0 )); then
    printf "%s %s\n" "${USER_INPUT_ICON:-💬︎}" "${group[*]}" >&2
    _SCHEMA_TOKENS=("${group[@]}")
    _schema_dispatch
  fi
  return 0
}

build_mode() {
  local intent="$1"
  shift

  log_info "Starting Schema Builder: $intent"
  # All chatter goes to stderr — stdout is the schema channel.
  printf "\n${BLUE}Building schema for:${WOLFE} %s\n" "$intent" >&2
  echo -e "${GRAY}Commands: select <name> <type> <instructions> | option <vals>${RESET}\n" >&2

  current_name=""
  schema_errors=0
  commands_seen=0

  _schema_run_args "$@"

  # End of the words (finish): with no errors the validated schema goes to
  # stdout; any command error refuses to write.
  if (( commands_seen == 0 )); then
    log_error "Schema build aborted: no DSL commands received."
    exit 1
  fi
  if (( schema_errors > 0 )); then
    log_error "Schema build failed: $schema_errors command(s) errored — refusing to emit."
    exit 1
  fi
  if ! jq empty "$SCHEMA_TMP" > /dev/null 2>&1; then
    log_error "Schema build failed: accumulated schema is not valid JSON — refusing to emit."
    exit 1
  fi
  log_info "End of DSL — schema verified; writing to stdout."
  if ! jq . "$SCHEMA_TMP"; then
    log_error "Schema build failed: could not emit schema."
    exit 1
  fi
  exit 0
}

# --- MAIN ENTRY POINT ---
if [[ $# -lt 2 ]]; then
  usage
fi

case "$1" in
  build) shift; build_mode "$@" ;;
  *) usage ;;
esac
