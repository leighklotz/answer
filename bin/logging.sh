#!/usr/bin/env bash

# Check if the script is being sourced or directly executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "This script is intended to be sourced, not executed directly."  >&2
    exit 1
fi

COLOR_RED='\e[1;31m'
COLOR_YELLOW='\e[1;33m'
COLOR_GREEN='\e[1;32m'
COLOR_BLUE='\e[1;36m'
NOCOLOR='\e[0m'
WARNING_ICON_BIG=$'\u26a0\ufe0f️'
WARNING_ICON_SMALL=$'\u26a0'
WARNING_ICON="$WARNING_ICON_SMALL"
VERBOSE_ICON='📣'
TRACE_ICON='🔍'
ERROR_ICON='❌'
EXIT_ICON='⛔'
INFO_ICON='ℹ️'
GREEN_CHECK_ICON="✅"
HALLUX_ICON="👣"
TEE_ICON="👕"
USER_INPUT_ICON="💬"
INFERENCE_ICON="✨"
CACHE_HIT_ICON="🎯"
THINK_ICON="🧠"
CANCELLED_ICON="🚫"
TRASH_ICON="🗑️ "
INBOX_ICON="📥"
COMPUTER_ICON="🖥️"
ROBOT_ICON="🤖"
SCROLL_ICON="📜"
STDIN_ICON="➡️"
CONVO_ICON="💭"
RESPONSE_ICON="↩️"
SAVE_ICON="💾"
PIN_ICON="📌"


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
