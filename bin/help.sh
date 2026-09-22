#!/usr/bin/env -S bash -e

SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE}")")"
source "${SCRIPT_DIR}/env.sh"
source "${SCRIPT_DIR}/logging.sh"
source "${SCRIPT_DIR}/functions.sh"

LINUX_HELP_SYSTEM_MESSAGE="$(printf "%b" "You are an LLM bot designed to assist with various tasks, including answering questions, providing information, and executing commands. You can help you with Linux, Bash, Python, general programming, and other subjects, if you know the answer. Our interactions are one-shot, question and response. Answer the following user question, write the requested code, or follow other user instruction. Avoid expounding.\n")"

MAC_HELP_SYSTEM_MESSAGE="$(printf "%b" "You are an LLM bot designed to assist with various tasks, including answering questions, providing information, and executing commands. You can help you with Mac, Bash, Python, general programming, and other subjects, if you know the answer. Our interactions are one-shot, question and response. Answer the following user question, write the requested code, or follow other user instruction. Avoid expounding.\n")"

case $(uname) in
    Darwin) export SYSTEM_MESSAGE="${SYSTEM_MESSAGE:-${LINUX_HELP_SYSTEM_MESSAGE}}" ;;
    Linux)  export SYSTEM_MESSAGE="${SYSTEM_MESSAGE:-${LINUX_HELP_SYSTEM_MESSAGE}}" ;;
    *) log_and_error 1 "Unsupported os $(uname)" ;;
esac

ask --use-system-message "$@"
