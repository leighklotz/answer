#!/usr/bin/env bash

# Check if the script is being sourced or directly executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "This script is intended to be sourced, not executed directly."  >&2
  exit 1
fi

HALLUX_ICON='👣'

COLOR_RED='\e[1;31m'
COLOR_YELLOW='\e[1;33m'
COLOR_GREEN='\e[1;32m'
COLOR_BLUE='\e[1;36m'
NOCOLOR='\e[0m'

if [[ "${HX_ICON_STYLE:-emoji}" == "emoji" ]]; then
  CACHE_HIT_ICON='🎯'
  CANCELLED_ICON='🚫'
  COMPUTER_ICON='🖥️'
  CONVO_ICON='💭'
  DECISION_ICON='⚖️'      # not displaying?
  ERROR_ICON='❌'
  EXIT_ICON='⛔'
  GREEN_CHECK_ICON='✅'
  INBOX_ICON='📥'
  INFERENCE_ICON='✨'
  INFO_ICON='ℹ️'
  MARKDOWN_ICON='📑'
  PIN_ICON='📌'
  RESPONSE_ICON='↩️'
  ROBOT_ICON='🤖'
  SAVE_ICON='💾'
  SCROLL_ICON='📜'
  SHELL_ICON='🐚'
  STATS_ICON="📊"
  STDIN_ICON='➡️'
  STREAMING_ICON='.'
  TEE_ICON='👕'
  THINK_ICON='🧠'
  TRACE_ICON='🔍'
  TRASH_ICON='🗑️'
  USER_INPUT_ICON='💬'
  VERBOSE_ICON='📣'
  WARNING_ICON='⚠️'
else
  CACHE_HIT_ICON=$'\U0001f3af\ufe0e'     # 🎯︎
  CANCELLED_ICON=$'\U0001f6ab\ufe0e'     # 🚫︎
  COMPUTER_ICON=$'\U0001f5a5\ufe0e'      # 🖥︎
  CONVO_ICON=$'\U0001f4ad\ufe0e'         # 💭︎
  DECISION_ICON=$'\u2696\ufe0e'           # ⚖️
  ERROR_ICON=$'\U274c\ufe0e'             # ❌︎
  EXIT_ICON=$'\U26d4\ufe0e'              # ⛔︎
  GREEN_CHECK_ICON=$'\U2705\ufe0e'       # ✅︎
  INBOX_ICON=$'\U0001f4e5\ufe0e'         # 📥︎
  INFERENCE_ICON=$'\U2728\ufe0e'         # ✨︎
  INFO_ICON=$'\U2139\ufe0e'              # ℹ︎
  MARKDOWN_ICON=$'\U0001f4d1\ufe0e'      # 📑︎
  PIN_ICON=$'\U0001f4cc\ufe0e'           # 📌︎
  RESPONSE_ICON=$'\U21a9\ufe0e'          # ↩︎
  ROBOT_ICON=$'\U0001f916\ufe0e'         # 🤖︎
  SAVE_ICON=$'\U0001f4be\ufe0e'          # 💾︎
  SCROLL_ICON=$'\U0001f4dc\ufe0e'        # 📜︎
  SHELL_ICON=$'\U0001f41a\ufe0e'         # 🐚︎
  STATS_ICON=$'\U0001f4ca\ufe0e'         # 📊︎
  STDIN_ICON=$'\U27a1\ufe0e'             # ➡︎
  STREAMING_ICON='.'                     # .
  TEE_ICON=$'\U0001f455\ufe0e'           # 👕︎
  THINK_ICON=$'\U0001f9e0\ufe0e'         # 🧠︎
  TRACE_ICON=$'\U0001f50d\ufe0e'         # 🔍︎
  TRASH_ICON=$'\U0001f5d1\ufe0e'         # 🗑︎
  USER_INPUT_ICON=$'\U0001f4ac\ufe0e'    # 💬︎
  VERBOSE_ICON=$'\U0001f4e3\ufe0e'       # 📣︎
  WARNING_ICON=$'\U26a0\ufe0e'           # ⚠︎
fi

# RWK: https://gist.github.com/akostadinov/33bb2606afe1b334169dfbf202991d36?permalink_comment_id=4962266#gistcomment-4962266
function stack_trace() {
  local -a stack=("Stack trace:")
  local stack_size=${#FUNCNAME[@]}
  local -i i
  local indent="    "
  # to avoid noise we start with 1 to skip the stack function
  for (( i = 1; i < stack_size; i++ )); do
    local func="${FUNCNAME[$i]:-(top level)}"
    local -i line="${BASH_LINENO[$(( i - 1 ))]}"
    local src="${BASH_SOURCE[$i]:-(no file)}"
    stack+=("$indent └ $src:$line ($func)")
    indent="${indent}    "
  done
  (IFS=$'\n'; echo "${stack[*]}")
}

function log_with_icon {
  local icon="${1:-}"
  local message="${2:-}"
  local timestamp="$(date -u +"%Y-%m-%d %H:%M:%S.%3NZ")"
  printf "%s %s %b\n" "${icon}" "${timestamp}" "${message}" >&2
}

function log_verbose {
  local prog="$(basename "$0")"
  local message="${1:-}"
  if [ -n "${VERBOSE}" ]; then
    log_with_icon "$VERBOSE_ICON" "${prog}: ${message}"
  fi
}

function log_debug {
  if [ -n "${DEBUG}" ]; then
    local prog="$(basename "$0")"
    local message="${1:-}"
    log_with_icon '🐞' "${COLOR_BLUE}DEBUG ${prog}:${NOCOLOR} ${message}"
  fi
}

function log_info {
  if [ -n "${INFO}" ]; then
    local prog="$(basename "$0")"
    local message="${1:-}"
    log_with_icon "$INFO_ICON" "${COLOR_GREEN}INFO ${prog}:${NOCOLOR} ${message}"
  fi
}

function log_warn {
  local prog="$(basename "$0")"
  local message="${1:-}"
  # unicode warning sign is blighted in ghostty+emacs
  log_with_icon "$WARNING_ICON" "${COLOR_YELLOW}WARN ${prog}:${NOCOLOR} ${message}"
}

function log_trace {
  if [ -n "${TRACE}" ]; then
    local prog="$(basename "$0")"
    local message="${1:-}"
    log_with_icon "$TRACE_ICON" "${COLOR_BLUE}TRACE ${prog}:${NOCOLOR} ${message}"
  fi
}

function log_error {
  local prog="$(basename "$0")"
  local message="${1:-}"
  log_with_icon "$ERROR_ICON" "${COLOR_RED}ERROR in ${prog}:${NOCOLOR} ${message}"
  [ -n "${PRINT_STACK_TRACE:-}" ] && printf "%s\n" "$(stack_trace)" > /dev/fd/2
}

function log_and_exit {
  local prog="$(basename "$0")"
  local code="${1:-}"
  local message="${2:-}"
  log_with_icon "$EXIT_ICON" "${COLOR_RED}ERROR in ${prog}:${NOCOLOR} ${message}"
  [ -n "${PRINT_STACK_TRACE:-}" ] && printf "Error code %s %s\n" "$code" "$(stack_trace)" | tee > /dev/fd/2
  [[ "${code}" =~ ^[0-9]+$ ]] && exit "${code}" || exit 1
}

### OSC 8 Mouseover Protocol Configuration
###
### Formats and routes a mouseover tooltip sequence strictly to stderr (Descriptor 2).
### Ensures the primary stdout data stream remains completely clean.
###
### Arguments:
###   $1 - The visible text or icon printed directly to the terminal grid
###   $2 - The descriptive text hidden inside the hover state
###
### Usage:
###   emit_icon_tooltip "$WARNING_ICON" "Battery Low"
emit_icon_tooltip() {
    # External protocol variables defining the OSC 8 hyperlink boundaries.
    # Ghostty interprets the destination parameter string as visual tooltip text.
    local OSC8_START=$'\e]8;;'
    local OSC8_DIV=$'\e\\'
    local OSC8_CLOSE=$'\e]8;;\e\\'

    # SGR (Select Graphic Rendition) codes for styling.
    local SGR_UNDERLINE_ON=$'\e[4m'
    local SGR_RESET=$'\e[0m'

    local icon="$1"
    local tooltip="${2//\'/}"
    tooltip="${tooltip//;/}"
    tooltip="${tooltip//$'\x1b'/}"

    if [[ "$TERM" == "emacs" || "$TERM" == "dumb" || "$TERM" == "glass" ]]; then
        printf '%s' "$icon" >&2
    elif [[ "$icon" =~ [[:alnum:]] ]]; then
        # Ghostty ignores text= and shows the URI on hover,
        # so we use the tooltip text *as* the URI.
        #
        #   OSC8_START  uri  OSC8_DIV           -> open hyperlink
        #   [SGR_UNDERLINE_ON] text [SGR_RESET] -> optional underline
        #   OSC8_CLOSE                          -> close hyperlink
        printf '%s%s%s%s%s%s%s' \
            "$OSC8_START" "$tooltip" "$OSC8_DIV" \
            "$SGR_UNDERLINE_ON" "$icon" "$SGR_RESET" \
            "$OSC8_CLOSE" >&2
    else
        printf '%s%s%s%s%s' \
            "$OSC8_START" "$tooltip" "$OSC8_DIV" \
            "$icon" \
            "$OSC8_CLOSE" >&2
    fi
}
