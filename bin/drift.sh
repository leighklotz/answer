#!/usr/bin/env -S bash

# ---------------------
# 📌 Overview
# ---------------------
# This script performs a constraint-aware comparison of a candidate artifact
# (FILE_B) against its original source (FILE_A) and one or more ground-truth
# context items. It detects LLM dreck, lazy elisions, and substantive drift.

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
    cat <<EOF >&2
Usage: drift FILE_A FILE_B [CONTEXT_FILE...] [-- [EXTRA_PROMPT...]]
       drift (reads from stdin)

Description:
  Compares a candidate artifact against its source and ground-truth constraints.
  If no files are provided, it expects a bundled stream via stdin (via 'lx').

Arguments:
  FILE_A          The original source or reference artifact.
  FILE_B          The candidate version to be evaluated.
  CONTEXT_FILES   (Optional) Zero or more files providing additional constraints.

Options:
  --              End of positional arguments; everything after is treated as extra prompt text for 'ask'.
  -h, --help      Show this help message.
EOF
}

# Run ask with the base prompt and optional user extension
_ask() {
    if [[ -n "$EXTRA_PROMPT" ]]; then
        ask "$EXTRA_PROMPT $PROMPT"
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
    # MODE: Positional Files (N >= 2)
    # If N=2, they are treated as A and B.
    FILE_A="${FILES[0]}"
    FILE_B="${FILES[1]}"

    for f in "${FILES[@]}"; do
        if [[ ! -f "$f" ]]; then
            printf "%s: Error: File not found: %s\n" "$0" "$f" >&2
            exit 1
        fi
    done

    # Optimization: If files are identical, no drift possible.
    if cmp --quiet "$FILE_A" "$FILE_B"; then
        log_info "Files are identical."
        exit 0
    fi

    # Ingest A, B, and optional Context Files via lx and pipe to ask
    lx "${FILES[@]}" | _ask

elif (( FILE_COUNT == 0 )); then
    # MODE: Piped Input (N = 0)
    # Expects stdin to contain a bundled stream (e.g., from 'lx')
    if [[ -t 0 ]]; then
        printf "%s: Error: No positional arguments provided and no piped input detected.\n" "$0" >&2
        usage
        exit 1
    fi

    _ask

else
    # MODE: Error Case (N = 1)
    printf "%s: Error: Expected at least 2 files (source + candidate); got %d\n" "$0" "${FILE_COUNT}" >&2
    usage
    exit 1
fi
