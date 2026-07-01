#!/usr/bin/env -S bash -e

SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE}")")"
source "${SCRIPT_DIR}/env.sh"
source "${SCRIPT_DIR}/logging.sh"
source "${SCRIPT_DIR}/functions.sh"

# Auto-detect the best available viewing tool
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

# Process stdin via awk to:
# 1. Resolve the magic header if present
# 2. Extract the first fenced block
# 3. Output the result to stderr for viewing (via pager)
# 4. Output the final content to stdout for the confirmation check

# We use a temporary file to handle the potential size and multiple passes
tmp_content=$(mktemp)

awk -v magic_header="${PIPELINE_MAGIC_HEADER}" -v pager_cmd="${pager}" '
  BEGIN { 
    flag = 0; 
    in_magic = 0; 
  }
  # Handle magic header resolution logic
  # Note: Since we cannot call the external "answer" script easily inside AWK,
  # we handle the logic by checking if the first line matches.
  # However, to follow instructions strictly about merging logic:
  # We will process the input in a single AWK pass.
  
  # For simplicity in a single script, we use the shell to resolve the magic header 
  # if it exists, then let AWK handle the extraction and piping.
' 

# Revised approach: Use a subshell to resolve magic header, then awk for extraction
# then use awk to perform the pager/confirmation logic via stderr.

# 1. Resolve header if needed and extract block into a temp file
if [[ "$(head -c 100)" == "${PIPELINE_MAGIC_HEADER}"* ]]; then
    # This is complex via pipes; simpler to read all to a file first if it might be large
    # or use a temporary file to ensure we don't blow out bash variables.
    tmp_raw=$(mktemp)
    cat > "$tmp_raw"
    "${SCRIPT_DIR}/answer" < "$tmp_raw" > "$tmp_raw.resolved"
    mv "$tmp_raw.resolved" "$tmp_raw"
    input_file="$tmp_raw"
else
    input_file=$(mktemp)
    cat > "$input_file"
fi

# 2. Use AWK to extract the first block and pipe it to the pager on stderr
# and write the extracted content to a temporary file for the confirmation step.
fenced_file=$(mktemp)

awk '
  /^```$/ && flag { exit }
  /^```.*$/ && !flag { flag = 1; next }
  flag { print }
' "$input_file" | tee "$fenced_file" > /dev/null | ${pager} 1>&2

if [ $? -ne 0 ] && [ ! -s "$fenced_file" ]; then
    log_exit 1 "unfence failed"
fi

printf "\n" 1>&2

# 3. Safe interactive confirmation
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

# Cleanup
rm -f "$input_file" "$fenced_file"

