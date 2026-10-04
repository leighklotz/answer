#!/usr/bin/env -S bash
#
# hx schema — build a decide schema from a small stream DSL.
#
#   hx schema build <intent> <<'EOF'
#     select <name> [choice|score|noul] [--instructions <text>] [--legend <a|b|c>]
#     option <values>
#     finish [filename]
#   EOF
#
# Fixes baked into this version:
#   * values are tokenised with quote handling (a leading ' or " wraps one
#     token; wrapping quotes are stripped) instead of leaking into keys
#   * --instructions accepts both "--instructions text" and "--instructions=text"
#   * option JSON is built BY jq; every jq call is checked; `finish` validates
#     the schema and refuses to write if any earlier command errored; EOF
#     without `finish` is a hard error
#   * lines ending in a backslash are joined with the next line, and a line
#     starting with "-" is glued onto the previous line (repairs input that
#     arrives split in front of a flag)
#   * types are exact-matched, --legend works, `option` routing follows the
#     field's declared type (noul takes no options), duplicate fields and
#     stray lines fail loudly, and temp state cannot leak between runs

# --- SETUP & SOURCE (Standard Hallux Pattern) ---
SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE}")")"
source "${SCRIPT_DIR}/../env.sh"
source "${SCRIPT_DIR}/../logging.sh"
source "${SCRIPT_DIR}/../functions.sh"

set -o pipefail

# --- FIELD TYPES ---
TYPE_CHOICE="choice"
TYPE_SCORE="score"
TYPE_NOUL="noul"

usage() {
  cat >&2 <<'USAGE'
Usage: hx schema build <intent>

Reads a schema DSL from stdin and writes the JSON schema when `finish` runs.

DSL commands (one per line):
  select <name> [type] [--instructions <text>] [--legend <l1|l2|...>]
      type is one of: choice (default), score, noul
      --instructions  free-text guidance stored with the field
                      ("--instructions text" or "--instructions=text")
      --legend        pipe-separated score levels (score fields only)
  option <values>
      choice: "key:desc,key2:desc2" (or several quoted "key:desc" tokens;
              a bare key gets an empty description)
      score:  "level1|level2|level3" (or several quoted level tokens)
      noul:   not allowed - the probability is decided at runtime
  finish [filename]
      validates the accumulated schema and writes it (default: schema.json)

Input rules:
  * values containing spaces/commas/pipes must be quoted; one level of
    wrapping quotes is stripped
  * a line ending in an odd number of backslashes continues on the next line
  * a line starting with "-" is glued onto the previous line (repairs input
    that was split in front of a flag)
  * blank lines and lines starting with '#' are ignored
  * each field may be declared once; 'option' must follow its 'select';
    ANY command error makes `finish` refuse to write

Set HALLUX_SCHEMA_DEBUG=1 to echo the parsed commands while building.
USAGE
  exit 0
}

_ensure_workspace || exit 1

# --- STATE MANAGEMENT ---
SCHEMA_TMP="$HALLUX_TMP_DIR/current_schema.json"
SCHEMA_TMP_NEW="${SCHEMA_TMP}.tmp"

# Always start from a clean slate: a run that died before `finish` used to
# leak the previous session's half-built schema into this one.
mkdir -p "$HALLUX_TMP_DIR" 2>/dev/null || true
if ! printf '{"questions": {}}\n' > "$SCHEMA_TMP"; then
  log_error "cannot initialise schema state file '$SCHEMA_TMP'"
  exit 1
fi
trap 'rm -f "$SCHEMA_TMP" "$SCHEMA_TMP_NEW"' EXIT

# --- PARSE STATE (globals shared by the helpers below) ---
declare -a _SCHEMA_LINES=()
declare -a _SCHEMA_TOKENS=()
declare -a _SCHEMA_POSITIONAL=()
declare -A _SCHEMA_FLAGS=()
current_name=""
schema_errors=0

# Record an error (counted, so `finish` can refuse to write) and fail.
_schema_fail() {
  log_error "$*"
  schema_errors=$((schema_errors + 1))
  return 1
}

# ── Input shaping ─────────────────────────────────────────────────────

# Count trailing backslashes so "foo\\" (an escaped backslash) is not
# mistaken for a line continuation.
_schema_trailing_backslashes() {
  local s=$1 n=0
  while [[ $s == *\\ ]]; do
    n=$((n + 1))
    s=${s%?}
  done
  printf '%s' "$n"
}

# Slurp stdin into _SCHEMA_LINES as logical lines: trim, drop blanks and
# '#' comments, and join "\"-continued lines (`read -r` deliberately does
# not join them, which is what shredded the old heredoc input).
_schema_collect_input() {
  _SCHEMA_LINES=()
  local raw acc="" n_bs
  while IFS= read -r raw; do
    raw=${raw%$'\r'}
    raw="${raw#"${raw%%[![:space:]]*}"}"
    raw="${raw%"${raw##*[![:space:]]}"}"
    if [[ -z $raw || $raw == \#* ]]; then
      continue
    fi
    n_bs=$(_schema_trailing_backslashes "$raw")
    if (( n_bs % 2 == 1 )); then
      acc+="${raw%\\} "
      continue
    fi
    _SCHEMA_LINES+=("${acc}${raw}")
    acc=""
  done
  if [[ -n $acc ]]; then
    _SCHEMA_LINES+=("${acc% }")
  fi
  return 0
}

# Safety net for input that arrives pre-split at a flag: no DSL command
# starts with "-", so a line beginning with "-" is glued onto the previous
# logical line instead of surfacing as "Unknown command: '--instructions'".
_schema_join_flag_lines() {
  local -a joined=()
  local line prev=""
  for line in "${_SCHEMA_LINES[@]}"; do
    if [[ -n $prev && $line == -* ]]; then
      prev+=" $line"
    else
      [[ -n $prev ]] && joined+=("$prev")
      prev=$line
    fi
  done
  [[ -n $prev ]] && joined+=("$prev")
  _SCHEMA_LINES=("${joined[@]}")
  return 0
}

# ── Tokenising ────────────────────────────────────────────────────────

# Split one logical line into tokens. A ' or " at the START of a token (or
# immediately after '=') quotes until its matching close; quotes elsewhere
# are literal data, and so are backslashes. This — not `read` — is where
# wrapping quotes get stripped from values.
_schema_tokenize() {
  _SCHEMA_TOKENS=()
  local s=$1 i=0 n=${#s} c
  local tok="" in_q="" prev=""
  while (( i < n )); do
    c=${s:i:1}
    case $c in
      [$' \t'])
        if [[ -n $in_q ]]; then
          tok+=$c
        elif [[ -n $tok ]]; then
          _SCHEMA_TOKENS+=("$tok")
          tok=""
        fi
        ;;
      "'"|'"')
        if [[ -n $in_q ]]; then
          if [[ $c == "$in_q" ]]; then
            in_q=""
          else
            tok+=$c
          fi
        elif [[ -z $tok || $prev == "=" ]]; then
          in_q=$c
        else
          tok+=$c
        fi
        ;;
      *)
        tok+=$c
        ;;
    esac
    prev=$c
    i=$((i + 1))
  done
  [[ -n $tok ]] && _SCHEMA_TOKENS+=("$tok")
  return 0
}

# _SCHEMA_TOKENS[0] is the command word; the rest becomes positional
# arguments plus "--flag value" / "--flag=value" pairs (parsed structurally,
# so --instructions works with or without '=').
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

# {"key": "desc", ...} from the given items; a single item is split on ','.
# "key:desc" splits on the FIRST colon so descriptions may contain more of
# them; a bare key gets an empty description.
_schema_choice_json() {
  local -a opts=()
  if (( $# == 1 )); then
    IFS=',' read -r -a opts <<< "$1"
  else
    opts=("$@")
  fi
  jq -n '
    def _entry:
      if contains(":") then
        split(":") as $p
        | ($p[0] | gsub("^\\s+|\\s+$"; "")) as $key
        | (($p[1:] | join(":")) | gsub("^\\s+|\\s+$"; "")) as $val
        | if ($key | length) == 0 then error("choice option key is empty")
          else {($key): $val}
          end
      else
        {(.): ""}
      end;
    [$ARGS.positional[] | gsub("^\\s+|\\s+$"; "")]
    | if length == 0 then error("no choice options given")
      elif any(.[]; length == 0) then error("choice options must not be empty")
      else map(_entry) | add
      end
  ' --args "${opts[@]}"
}

_schema_apply_score() {
  local key=$1
  shift
  local json
  if ! json=$(_schema_score_json "$@"); then
    _schema_fail "option: invalid score levels for '$key' (see jq error above)"
    return 1
  fi
  if ! _schema_apply_jq '.questions[$k].criteria = $c' \
       --arg k "$key" --argjson c "$json"; then
    _schema_fail "option: failed to store score criteria for '$key'"
    return 1
  fi
  return 0
}

_schema_apply_choice() {
  local key=$1
  shift
  local json
  if ! json=$(_schema_choice_json "$@"); then
    _schema_fail "option: invalid choice options for '$key' (see jq error above)"
    return 1
  fi
  # probabilities are ensured here; the old no-op `with_entries` is gone
  if ! _schema_apply_jq '
      .questions[$k].criteria = $c
      | .questions[$k].probabilities = (.questions[$k].probabilities // {})
    ' --arg k "$key" --argjson c "$json"; then
    _schema_fail "option: failed to store choice criteria for '$key'"
    return 1
  fi
  return 0
}

# ── DSL commands ──────────────────────────────────────────────────────

_schema_cmd_select() {
  local name="${_SCHEMA_POSITIONAL[0]:-}"
  local type_arg="${_SCHEMA_POSITIONAL[1]:-}"
  local instr="${_SCHEMA_FLAGS[--instructions]:-}"
  local legend="${_SCHEMA_FLAGS[--legend]:-}"

  if [[ -z $name ]]; then
    _schema_fail "select: a field name is required"
    return 1
  fi
  if (( ${#_SCHEMA_POSITIONAL[@]} > 2 )); then
    _schema_fail "select: too many arguments (${_SCHEMA_POSITIONAL[*]:2}) — expected <name> [type]"
    return 1
  fi
  local type="$TYPE_CHOICE"
  if [[ -n $type_arg ]]; then
    case "$type_arg" in
      "$TYPE_CHOICE"|"$TYPE_SCORE"|"$TYPE_NOUL") type="$type_arg" ;;
      *)
        # exact-match the type instead of grepping the whole line for a type
        # substring (a field named "score_count" used to become a score field)
        _schema_fail "select: unknown type '$type_arg' (use choice, score or noul)"
        return 1
        ;;
    esac
  fi
  local f
  for f in "${!_SCHEMA_FLAGS[@]}"; do
    case "$f" in
      --instructions|--legend) ;;
      *) _schema_fail "select: unknown flag '$f'"; return 1 ;;
    esac
  done
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

  if [[ -n $legend ]]; then
    if [[ "$type" != "$TYPE_SCORE" ]]; then
      _schema_fail "select: --legend only applies to score fields (type is '$type')"
      return 1
    fi
    _schema_apply_score "$name" "$legend" || return 1
    printf "  ${GREEN}✓${WOLFE} Legend applied to '%s'.\n" "$name" >&2
  fi
  current_name="$name"
  return 0
}

_schema_cmd_option() {
  if [[ -z $current_name ]]; then
    _schema_fail "option: no active field — 'option' must follow its 'select'"
    return 1
  fi
  if [[ -z ${_SCHEMA_POSITIONAL[0]:-} ]]; then
    _schema_fail "option: missing value"
    return 1
  fi
  local f
  for f in "${!_SCHEMA_FLAGS[@]}"; do
    _schema_fail "option: unknown flag '$f'"
    return 1
  done
  local ftype
  if ! ftype=$(jq -r --arg k "$current_name" '.questions[$k].type // ""' "$SCHEMA_TMP"); then
    _schema_fail "option: cannot read the type of field '$current_name'"
    return 1
  fi
  local -a items=("${_SCHEMA_POSITIONAL[@]}")

  # Route by the field's DECLARED type, not by whether the value happens to
  # contain '|' (a score level containing a comma, or a choice description
  # containing a pipe, used to be misrouted).
  case "$ftype" in
    "$TYPE_SCORE")
      _schema_apply_score "$current_name" "${items[@]}" || return 1
      ;;
    "$TYPE_CHOICE")
      _schema_apply_choice "$current_name" "${items[@]}" || return 1
      ;;
    "$TYPE_NOUL")
      _schema_fail "option: fields of type 'noul' take no options (the probability is decided at runtime)"
      return 1
      ;;
    *)
      _schema_fail "option: field '$current_name' has unknown type '$ftype'"
      return 1
      ;;
  esac

  printf "  ${GREEN}✓${WOLFE} Options added to '%s'.\n" "$current_name" >&2
  return 0
}

_schema_cmd_finish() {
  local target="${_SCHEMA_POSITIONAL[0]:-schema.json}"
  if (( ${#_SCHEMA_POSITIONAL[@]} > 1 )); then
    _schema_fail "finish: expected at most one filename"
    return 1
  fi
  local f
  for f in "${!_SCHEMA_FLAGS[@]}"; do
    _schema_fail "finish: unknown flag '$f'"
    return 1
  done
  if (( schema_errors > 0 )); then
    log_error "finish: refusing to write '$target' — $schema_errors earlier command(s) failed"
    exit 1
  fi
  if ! jq empty "$SCHEMA_TMP" > /dev/null 2>&1; then
    log_error "finish: accumulated schema is not valid JSON — refusing to write '$target'"
    exit 1
  fi
  if ! jq . "$SCHEMA_TMP" > "$target"; then
    log_error "finish: failed to write '$target'"
    rm -f "$target"
    exit 1
  fi
  echo -e "${BLUE}Schema saved to $target${RESET}\n"
  exit 0
}

# ── CORE ENGINE ───────────────────────────────────────────────────────
build_mode() {
  local intent="$1"
  local line cmd

  log_info "Starting Schema Builder: $intent"
  printf "\n${BLUE}Building schema for:${WOLFE} %s\n" "$intent"
  echo -e "${GRAY}Commands: select <name> [type] | option <vals> | finish\n${RESET}"

  current_name=""
  schema_errors=0

  _schema_collect_input
  _schema_join_flag_lines

  for line in "${_SCHEMA_LINES[@]}"; do
    printf "%s %s\n" "${USER_INPUT_ICON:-💬︎}" "$line" >&2
    _schema_tokenize "$line"
    _schema_parse_tokens
    cmd="${_SCHEMA_TOKENS[0]:-}"

    if [[ ${HALLUX_SCHEMA_DEBUG:-0} == 1 ]]; then
      printf "DBG cmd=%q positional=[%s] flags=[%s]\n" \
        "$cmd" "${_SCHEMA_POSITIONAL[*]}" "${!_SCHEMA_FLAGS[*]}" >&2
    fi

    case "$cmd" in
      select) _schema_cmd_select || current_name="" ;;
      option) _schema_cmd_option || current_name="" ;;
      finish) _schema_cmd_finish || exit 1 ;;
      *)
        _schema_fail "Unknown command: '$cmd'. Available: select, option, finish."
        current_name=""
        ;;
    esac
  done

  log_error "Schema build aborted: input ended before 'finish' was reached."
  exit 1
}

# --- MAIN ENTRY POINT ---
if [[ $# -lt 2 ]]; then
  usage
fi

case "$1" in
  build) shift; build_mode "$*" ;;
  *) usage ;;
esac