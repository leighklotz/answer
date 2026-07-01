#!/usr/bin/env -S bash -e

SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE}")")"
source "${SCRIPT_DIR}/env.sh"
source "${SCRIPT_DIR}/logging.sh"
source "${SCRIPT_DIR}/functions.sh"

# 1. Read stdin into tmp_raw immediately
tmp_raw=$(mktemp_reg)
fenced_file=$(mktemp_reg)
cat > "$tmp_raw"

# 2. Resolve magic header if necessary
if [[ "$(head -c 100 "$tmp_raw")" == "${PIPELINE_MAGIC_HEADER}"* ]]; then
    log_warn "Magic header detected. Resolving via answer..."
    
    # Create a specific temp file for the resolved content and register it immediately
    tmp_resolved=$(mktemp_reg)

    if ! answer < "$tmp_raw" > "$tmp_resolved"; then
        log_and_exit 1 "Failed to resolve magic header via answer"
    fi
    # Move resolved content back to tmp_raw
    mv "$tmp_resolved" "$tmp_raw"
fi

# 3. Extract the first code block using awk
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
    log_and_exit 1 "No fenced code block found in input"
fi

# 4. Display content via pager to stderr
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

# 5. Safe interactive confirmation
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

