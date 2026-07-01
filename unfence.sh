#!/usr/bin/env -S bash -e

SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE}")")"
source "${SCRIPT_DIR}/env.sh"
source "${SCRIPT_DIR}/logging.sh"
source "${SCRIPT_DIR}/functions.sh"

# Setup temporary files using the functions.sh registration mechanism
local -a cleanup_files=()
tmp_raw=$(mktemp)
_register_file_deletion cleanup_files "$tmp_raw"
fenced_file=$(mktemp)
_register_file_deletion cleanup_files "$fenced_file"

# Ensure cleanup on exit
trap '_delete_registered_files cleanup_files' EXIT

# 1. Read stdin and resolve magic header if necessary
if [[ "$(head -c 100)" == "${PIPELINE_MAGIC_HEADER}"* ]]; then
    cat > "$tmp_raw"
    # Note: Assuming 'answer' is in PATH or available via functions.sh context
    if ! answer < "$tmp_raw" > "$tmp_raw.resolved"; then
        log_exit 1 "Failed to resolve magic header via answer"
    fi
    mv "$tmp_raw.resolved" "$tmp_raw"
else
    cat > "$tmp_raw"
fi

# 2. Extract the first code block using awk
# This extracts content between the first ``` and the next ```
awk '
  /^```/ { 
    if (flag) { exit }
    flag = 1; 
    next 
  }
  flag { print }
' "$tmp_raw" > "$fenced_file"

# If no block was found, exit
if [ ! -s "$fenced_file" ]; then
    log_exit 1 "No fenced code block found in input"
fi

# 3. Display content via pager to stderr
# Using logic from functions.sh to determine pager
local pager
if [ -n "${PIPETEST_PAGER}" ]; then
    pager="${PIPETEST_PAGER}"
elif command -v batcat >/dev/null 2>&1; then
    pager="batcat --style=numbers,grid"
elif command -v bat >/dev/null 2>&1; then
    pager="bat --style=numbers,grid"
else
    pager="cat"
fi

cat "$fenced_file" | ${pager} 1>&2
printf "\n" 1>&2

# 4. Safe interactive confirmation
local reply
if [ -t 0 ]; then
    read -r -p "🤖 Proceed with this command? (y/N): " reply < /dev/tty
else
    reply="y"
fi

printf "\n" 1>&2

case "${reply,,}" in
    y*)
        cat "$fenced_file"
        ;;
    *)
        printf "🚫 discarded\n" 1>&2
        exit 0
        ;;
esac
