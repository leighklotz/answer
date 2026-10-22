#!/usr/bin/env -S bash
shopt -s nullglob
set -o pipefail

SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE}")")"
source "${SCRIPT_DIR}/logging.sh"
CMD_DIR="${SCRIPT_DIR}/../doc/commands"

source "${SCRIPT_DIR}/commands/hx-bootstrap.sh"
hx core

# 1. Validate input argument existence and directory validity
if [ -z "$1" ]; then
    echo "usage: $0 <output-dir>"
    exit 1
fi

output_dir="$(realpath "${1}")"

if [[ ! -d "$CMD_DIR" ]]; then
    log_and_exit 1 "${CMD_DIR} does not exist."
fi

cd "${CMD_DIR}" || log_and_exit 1 "Cannot enter directory ${CMD_DIR}"

# --- Phase 0: decide schema ---
# todo: make checkdoc-schema-$$.json a cleaned-up tmpfile
if [[ ! -f "${SCRIPT_DIR}/checkdoc-schema.json" ]]; then
 hx schema build "Doc-Command Version Check" \
   select verdict choice "Given the comparison between the old and .new versions of a doc/commands file, which describes the relationship?" \
   option NEW       "The .new file is a legitimate update; the old file should be replaced." \
   option OLD       "The .new file is stale, reverted, or rejected; keep the old file." \
   option IDENTICAL "The two files are substantively the same (whitespace, trivial edits only)." \
   option NEITHER   "The relationship is unclear, divergent, or otherwise does not fit the above." \
   > ${SCRIPT_DIR}/checkdoc-schema.json
fi

# --- PHASE 1: PRE-FLIGHT VALIDATION (Error Checking) ---
# We iterate through all candidate files to ensure the state is consistent.
# If any .md file required by a .md.new is missing, we exit immediately
# before making expensive or side-effect-heavy AI calls.

for new_md in *.md.new; do
    old_md="${new_md%.new}"
    base="${new_md%.new}"                                   # foo.md
    checkdoc_out="${output_dir}/checkdoc-${base}"           # checkdoc-foo.md

    # CRITICAL ERROR: If the source file is missing, we cannot complete
    # a full run of this script safely. Exit now.
    if [[ ! -f "$old_md" ]]; then
        log_and_exit 1 "Pre-flight failed: Source file '$old_md' (required by $new_md) does not exist."
    fi

    # WARNING: If an analysis from a previous run exists, warn the user.
    # We don't exit here because we intend to overwrite it with fresh data in Phase 2.
    if [[ -e "$checkdoc_out" ]]; then
        log_warn "Existing analysis output found and will be overwritten: $checkdoc_out"
    fi
done


# --- PHASE 2: ANALYSIS AND ACTION (Inference Calls) ---
 for new_md in *.md.new; do
     old_md="${new_md%.new}"
     base="${new_md%.new}"
     checkdoc_out="${output_dir}/checkdoc-${base}"

     echo "=== Analysis of $old_md -> ${new_md} ===" > "$checkdoc_out"
     dreck "${old_md}" "${new_md}" | answer >> "$checkdoc_out"
     # Immediately save the array
     status=("${PIPESTATUS[@]}")

     # Access specific indices (e.g., the middle command, index 1)
     echo "First command exit code:  ${status[0]}" >&2
     echo "Last command exit code:   ${status[1]}" >&2

     exit 34

     # decide classifies the plain-text comparison into typed JSON.

     if false; then
         echo "# checkdoc_out=$checkdoc_out"
         cat "$checkdoc_out"
         echo
         echo "# ${SCRIPT_DIR}/checkdoc-schema.json"
         cat "${SCRIPT_DIR}/checkdoc-schema.json"
         echo
         exit 33
     fi

     if ! decision_json="$(cat "$checkdoc_out" | decide "${SCRIPT_DIR}/checkdoc-schema.json")";
     then
         log_and_exit 1 "decide failed"
     fi

     printf "# decision_json\n%s\n" "$decision_json" >&2

     choice="$(printf '%s' "$decision_json" | jq -r '.verdict.choice')"
     confidence="$(printf '%s' "$decision_json" | jq -r '.verdict.confidence')"

     if [[ -n "$choice" && -n "$confidence" ]]; then
         echo
         ls -l "${old_md}" "${new_md}"
         printf '\n⚖️  Verdict: %s (confidence %s)\n\n' "$choice" "$confidence"
         
         # Gate on confidence: below 0.80, treat as NEITHER (safe default → .odd).
         if awk "BEGIN{exit !($confidence < 0.80)}"; then
             printf '  ⚠ low confidence, defaulting to .odd\n'
             choice="NEITHER"
         fi
         
         case "$choice" in
             NEW)       mv "${new_md}" "${old_md}" ;;
             OLD)       mv "${new_md}" "${new_md}.reject" ;;
             IDENTICAL) rm "${new_md}" ;;
             *)         mv "${new_md}" "${new_md}.odd" ;;
         esac
         
         printf '\n== End %s → %s: %s ==\n' "$old_md" "$new_md" "$choice"
     else
         log_and_exit 1 "failed to decide"
     fi
     read -rp "Press enter to continue (Ctrl-C to abort): "
 done
