#!/usr/bin/env -S bash

# ---------------------
# 📌 Overview
# ---------------------
#
# This script performs a constraint-aware comparison of a candidate artifact
# (FILE_B) against its original source (FILE_A) and one or more ground-truth
# context items (specs, requirements, test expectations, API contracts, etc.).
#
# It detects LLM dreck, lazy elisions, constraint violations, and factual/code
# drift, concluding with a categorical verdict: DRIFTED / ACCEPTABLE / NEEDS_REVISION.
#
# Usage:
#   drift FILE_A FILE_B [CONTEXT_FILE...] [-- EXTRA_PROMPT...]
#   drift (reads from stdin)

# ---------------------
# 📌 Configuration
# ---------------------
PROMPT="You are evaluating whether a candidate artifact (the second file) has drifted from its original source (the first file) and from the ground-truth constraints provided in the remaining context items.
0) If any input is JSON, empty, binary data, or a non-text format, report that fact and stop immediately.
1) Dreck check: Detect any 'LLM dreck' in the candidate (unnecessary conversational intro/outro, boilerplate, or filler).
2) Elision check: Verify that no critical content from the original source was omitted, summarized away, or truncated in the candidate.
3) Constraint drift: For each ground-truth context item, identify specific places where the candidate violates, contradicts, or fails to satisfy a stated requirement, expected value, or constraint. Cite the constraint source (filename) and the offending passage.
4) Factual/code drift: If the context includes expected test output, API contracts, or reference values, check the candidate for concrete mismatches (wrong identifiers, incorrect logic, missing edge-case handling).
5) Verdict: Conclude with a summary table: DRIFTED / ACCEPTABLE / NEEDS_REVISION, listing each violation with severity (critical / minor / informational)."

EXTRA_PROMPT=""

# ---------------------
# 📌 Core Functions
# ---------------------
SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
source "${SCRIPT_DIR}/env.sh"
source "${SCRIPT_DIR}/logging.sh"
source "${SCRIPT_DIR}/functions.sh"

usage() {
    cat <<EOF
Usage: drift FILE_A FILE_B [CONTEXT_FILE...] [-- [EXTRA_PROMPT...]]
       drift (reads from stdin)

Description:
  Compares a candidate artifact against its source and ground-truth constraints.

Arguments:
  FILE_A          The original source or reference artifact.
  FILE_B          The candidate version to be evaluated.
  CONTEXT_FILES   (Optional) Zero or more files providing additional constraints.

Options:
  --              End of positional arguments; everything after is treated as extra prompt text for 'ask'.
  -h, --help      Show this help message.
EOF
}

# Run ask with or without an extra user prompt, avoiding an empty-string
# argument when EXTRA_PROMPT is unset.
_ask() {
    if [[ -n "$EXTRA_PROMPT" ]]; then
        ask "$EXTRA_PROMPT" "$PROMPT"
    else
        ask "$PROMPT"
    fi
}

# ---------------------
# 📌 Argument Parsing
# ---------------------
ARGS=("$@")
ARG_COUNT=${#ARGS[@]}
INDEX=0
FILES=()

while (( INDEX < ARG_COUNT )); do
    case "${ARGS[$INDEX]}" in
        -h|--help)
            usage
            exit 0
            ;;
        --)
            # Everything following '--' is part of the extra prompt.
            EXTRA_PROMPT="${ARGS[@]:$((INDEX + 1))}"
            break
            ;;
    esac
    FILES+=("${ARGS[$INDEX]}")
    INDEX=$(( INDEX + 1 ))
done

FILE_COUNT=${#FILES[@]}

# ---------------------
# 📌 Execution Logic
# ---------------------

if (( FILE_COUNT >= 2 )); then
    # Mode: File Comparison (Source, Candidate, and optional Contexts)
    FILE_A="${FILES[0]}"
    FILE_B="${FILES[1]}"

    # Validate that all provided files exist and are readable
    for f in "${FILES[@]}"; do
        if [[ ! -f "$f" ]]; then
            log_error "File not found: $f"
            exit 1
        fi
    done

    # Check if source and candidate are identical
    if cmp --quiet "$FILE_A" "$FILE_B"; then
        log_info "Files are identical."
        exit 0
    fi

    # Ingest all files (source, candidate, and context) via lx, then run drift analysis
    lx "${FILES[@]}" | _ask

elif (( FILE_COUNT == 0 )); then
    # Mode: Piped Input / Stream mode
    
    # If stdin is a terminal (-t 0), it means the user ran 'drift' without 
    # piping anything in. We should error out instead of hanging.
    if [[ -t 0 ]]; then
        log_error "$0: No positional arguments provided and no piped input detected (stdin is a TTY)."
        exit 1
    fi

    _ask
else
    # Error Case: Exactly one file or ambiguous argument pattern
    log_error "$0: expected at least 2 files (source + candidate); got ${FILE_COUNT}: ${FILES[0]}"
    exit 1
fi
