#!/usr/bin/env -S bash -e

SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
source "${SCRIPT_DIR}/env.sh"
source "${SCRIPT_DIR}/logging.sh"
source "${SCRIPT_DIR}/functions.sh"

TARGET_LANG="${1:-}"

# 1. Read stdin into tmp_raw immediately
mktemp_reg 'unfence.XXXXXX.md' && tmp_raw="$MKTEMP_REG"
cat > "$tmp_raw"

# 2. Perform Inference if magic header is present
if [[ "$(head -c 100 "$tmp_raw")" == "${PIPELINE_MAGIC_HEADER}"* ]]; then
    mktemp_reg 'unfence.XXXXXX.json' && tmp_resolved="$MKTEMP_REG"
    if ! answer < "$tmp_raw" > "$tmp_resolved"; then
        log_and_exit 1 "Failed to resolve magic header via answer"
    fi
    mv "$tmp_resolved" "$tmp_raw"
fi

# 3. Dry-Run Map: Parse file for code blocks to build an index
mktemp_reg 'unfence.meta.XXXXXX.txt' && tmp_meta="$MKTEMP_REG"

awk '
  BEGIN { block=0; in_block=0 }
  /^```/ {
    if (!in_block) {
      in_block=1
      block++
      start_line=NR+1
      lang=$0; sub(/^```[ \t]*/, "", lang); sub(/[ \t]*$/, "", lang)
    } else {
      in_block=0
      end_line=NR-1
      print block, (lang==""?"unknown":lang), start_line, end_line
    }
    next
  }
  in_block && NR==start_line {
    # Lightweight heuristic: if info-string is missing or generic, check shebangs
    if (lang == "" || lang == "text") {
      if (/^#![ \t]*\/.*\/bash/ || /^#![ \t]*\/.*\/sh/) {
        lang="bash"
      } else if (/^#![ \t]*\/.*\/python/) {
        lang="python"
      }
    }
  }
' "$tmp_raw" > "$tmp_meta"

num_blocks=$(wc -l < "$tmp_meta")
if [ "$num_blocks" -eq 0 ]; then
    log_and_exit 1 "No fenced code block found in input"
fi

# 4. Display content via pager to stderr (So user can see the whole board)
if [ -n "${PIPETEST_PAGER}" ]; then
    pager="${PIPETEST_PAGER}"
elif command -v batcat >/dev/null 2>&1; then
    pager="batcat --style=numbers,grid"
elif command -v bat >/dev/null 2>&1; then
    pager="bat --style=numbers,grid"
else
    pager="cat"
fi

# Only page if we are going to prompt interactively (either piping to execution, or multiple blocks)
NEEDS_CONFIRM=false
if [ ! -t 1 ]; then
    NEEDS_CONFIRM=true
fi

if [ "$NEEDS_CONFIRM" = true ] || [ "$num_blocks" -gt 1 ]; then
    echo "" >&2
    cat "$tmp_raw" | ${pager} 1>&2
fi

# 5. Adaptive Interactive Logic
target_idx=""

if [ -n "$TARGET_LANG" ]; then
    # Path A: The Language Sniper (e.g. `unfence python`)
    # Collect all block indices that match the target language
    matching_indices=($(awk -v lang="$TARGET_LANG" 'tolower($2) == tolower(lang) {print $1}' "$tmp_meta"))
    num_matching=${#matching_indices[@]}

    if [ "$num_matching" -eq 0 ]; then
        log_and_exit 1 "No code block matching '${TARGET_LANG}' found."
    elif [ "$num_matching" -eq 1 ]; then
        target_idx="${matching_indices[0]}"
        if [ "$NEEDS_CONFIRM" = true ]; then
            read -r -p "🤖 Found targeted block (${TARGET_LANG}). Proceed with this command? (y/N): " reply < /dev/tty
            [[ "${reply,,}" =~ ^y ]] || { printf "🚫 discarded\n" >&2; exit 0; }
        fi
    else
        # Multiple matching blocks found!
        # Always prompt because we need a decision.
        while true; do
            # Format the indices with commas for the prompt
            idx_list=$(IFS=, ; echo "${matching_indices[*]}")
            read -r -p "🤖 Found $num_matching targeted blocks (${TARGET_LANG}). Extract which? ($idx_list, q): " reply < /dev/tty
            reply="${reply,,}"
            
            if [[ "$reply" == "q" || "$reply" == "quit" ]]; then
                printf "🚫 discarded\n" >&2
                exit 0
            elif [[ " ${matching_indices[*]} " =~ " $reply " ]]; then
                # Ensure the user picked one of the valid matching indices
                target_idx="$reply"
                break
            else
                log_warn "Invalid choice. Please select one of: $idx_list"
            fi
        done
    fi

elif [ "$num_blocks" -eq 1 ]; then
    # Path B: Un-targeted, Single Block
    target_idx=1
    
    if [ "$NEEDS_CONFIRM" = true ]; then
        read -r -p "🤖 Found 1 code block. Proceed with this command? (y/N): " reply < /dev/tty
        [[ "${reply,,}" =~ ^y ]] || { printf "🚫 discarded\n" >&2; exit 0; }
    fi

else
    # Path C: Un-targeted, Multiple Blocks
    # Always prompt here because we need a decision.
    while true; do
        read -r -p "🤖 Found $num_blocks code blocks. Extract which? (e.g., bash, python, 1, 2, q): " reply < /dev/tty
        reply="${reply,,}"
        
        if [[ "$reply" == "q" || "$reply" == "quit" ]]; then
            printf "🚫 discarded\n" >&2
            exit 0
        elif [[ "$reply" =~ ^[0-9]+$ ]] && [ "$reply" -ge 1 ] && [ "$reply" -le "$num_blocks" ]; then
            target_idx="$reply"
            break
        else
            # Try to resolve by language string (using the same safe array logic to prevent blind picking)
            matching_indices=($(awk -v lang="$reply" 'tolower($2) == tolower(lang) {print $1}' "$tmp_meta"))
            num_matching=${#matching_indices[@]}
            
            if [ "$num_matching" -eq 1 ]; then
                target_idx="${matching_indices[0]}"
                break
            elif [ "$num_matching" -gt 1 ]; then
                idx_list=$(IFS=, ; echo "${matching_indices[*]}")
                log_warn "Found multiple '$reply' blocks. Please specify by number: $idx_list"
            else
                log_warn "Invalid choice or no block matching '${reply}' found."
            fi
        fi
    done
fi

# 6. Surgical Extraction
read -r _ _ start_line end_line < <(awk -v idx="$target_idx" '$1 == idx {print}' "$tmp_meta")
sed -n "${start_line},${end_line}p" "$tmp_raw"
