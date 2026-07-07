#!/usr/bin/env -S bash -e

SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE}")")"
source "${SCRIPT_DIR}/env.sh"
source "${SCRIPT_DIR}/logging.sh"
source "${SCRIPT_DIR}/functions.sh"

# 1. Read stdin into tmp_raw immediately
mktemp_reg 'unfence.XXXXXX.md' && tmp_raw=$MKTEMP_REG
mktemp_reg 'unfenced.XXXXXX.dat' && unfenced_file=$MKTEMP_REG
cat > "$tmp_raw"

# 2. Perform Inference
if [[ "$(head -c 100 "$tmp_raw")" == "${PIPELINE_MAGIC_HEADER}"* ]]; then
    # Create a specific temp file for the resolved content and register it immediately
    mktemp_reg 'unfence.XXXXXX.json' && tmp_resolved="$MKTEMP_REG"
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
' "$tmp_raw" > "$unfenced_file"

# If no block was found, exit
if [ ! -s "$unfenced_file" ]; then
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

# 5. Safe interactive confirmation when unfence is used in a pipeline
if [ ! -t 1 ]; then
    echo "" >&2
    cat "$unfenced_file" | ${pager} 1>&2
    read -r -p "🤖 Proceed with this command? (y/N): " reply < /dev/tty
else
    reply="y"
fi

case "${reply,,}" in
    y*)
        cat "$unfenced_file"
        ;;
    *)
        printf "🚫 discarded\n" 1>&2
        exit 0
        ;;
esac
