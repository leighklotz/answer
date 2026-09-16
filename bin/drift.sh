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
#   drift [-- EXTRA_PROMPT...]  (reads from stdin/piped input)

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
SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE}")")"
source "${SCRIPT_DIR}/env.sh"
source "${SCRIPT_DIR}/logging.sh"
source "${SCRIPT_DIR}/functions.sh"

# ---------------------
# 📌 Argument Parsing
# ---------------------
ARGS=("$@")
ARG_COUNT=${#ARGS[@]}
INDEX=0
FILES=()

while (( INDEX < ARG_COUNT )); do
    if [[ "${ARGS[$INDEX]}" == "--" ]]; then
        EXTRA_PROMPT="${ARGS[@]:$((INDEX + 1))}"
        break
    fi
    FILES+=("${ARGS[$INDEX]}")
    ((INDEX++))
done

FILE_COUNT=${#FILES[@]}

# ---------------------
# 📌 File Comparison Logic
# ---------------------
if (( FILE_COUNT >= 2 )); then
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
    lx "${FILES[@]}" | ask "${EXTRA_PROMPT}" "${PROMPT}"
else
    # Piped input mode: no files (or insufficient files) on command line
    ask "${EXTRA_PROMPT}" "${PROMPT}"
fi
