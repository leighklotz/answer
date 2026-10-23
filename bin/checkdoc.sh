#!/usr/bin/env -S bash
shopt -s nullglob
set -o pipefail

SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
source "${SCRIPT_DIR}/logging.sh"
CMD_DIR="${SCRIPT_DIR}/../doc/commands"

source "${SCRIPT_DIR}/commands/hx-bootstrap.sh"
hx core

function mv_() {
    printf "%s %s %s %s ?" "${ROBOT_ICON}" "mv" "$1" "$2" >&2
    IFS= read -r OK
    case "$OK" in
        Y|y) mv "$1" "$2" ;;
        *) echo "Skipped" ;;
    esac
}

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
if [[ ! -f "${output_dir}/checkdoc-schema.json" ]]; then
 hx schema build "Doc-Command Version Check" \
   select verdict choice "Given the comparison between the old and .new versions of a doc/commands file, which describes the relationship?" \
   option NEW       "The .new file is a legitimate update; the old file should be replaced." \
   option OLD       "The .new file is stale, reverted, or rejected; keep the old file." \
   option IDENTICAL "The two files are substantively the same (whitespace, trivial edits only)." \
   option NEITHER   "The relationship is unclear, divergent, or otherwise does not fit the above." \
   > "${output_dir}/checkdoc-schema.json"
fi

# --- PHASE 1: PRE-FLIGHT VALIDATION (Error Checking) ---
# We iterate through all candidate files to ensure the state is consistent.
# If any .md file required by a .md.new is missing, we exit immediately
# before making expensive or side-effect-heavy AI calls.

for new_md in *.md.new; do
    old_md="${new_md%.new}"
    base="${new_md%.new}"
    checkdoc_out="${output_dir}/checkdoc-${base}"

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

     # Run dreck separately so we can inspect its exit code cleanly.
     dreck_out="$(dreck "${old_md}" "${new_md}")"
     dreck_rc=$?

    case "$dreck_rc" in
        0)
            # Normal path: dreck produced a real comparison → pipe into answer
            printf '%s\n' "$dreck_out" | answer >> "$checkdoc_out"
            ;;
        10)
            # Files are byte-identical
            printf '%s\n' "$dreck_out" >> "$checkdoc_out"
            log_info "Identical files: ${old_md} == ${new_md}"
            rm "${new_md}"
            continue
            ;;
        11)
            # Second file starts with a code fence
            printf '%s\n' "$dreck_out" >> "$checkdoc_out"
            log_warn "Code-fence header in ${new_md}; treating as ODD."
            mv_ "${new_md}" "${new_md}.odd"
            continue
            ;;
        12)
            # Second file starts with an 'lx' header
            printf '%s\n' "$dreck_out" >> "$checkdoc_out"
            log_warn "lx header in ${new_md}; treating as ODD."
            mv_ "${new_md}" "${new_md}.odd"
            continue
            ;;
        *)
            log_and_exit 1 "dreck exited with unexpected code ${dreck_rc} (${old_md} vs ${new_md})."
            ;;
    esac

    # --- decide (only reached for dreck_rc == 0) ---
    if ! decision_json="$(cat "$checkdoc_out" | decide "${output_dir}/checkdoc-schema.json")"; then
        log_info "decision_json=$decision_json"
        log_and_exit 1 "decide failed"
    fi

    choice="$(printf '%s' "$decision_json" | jq -r '.answers.verdict.choice // empty')"
    confidence="$(printf '%s' "$decision_json" | jq -r '.answers.verdict.confidence // empty')"

    if [[ -z "$choice" || -z "$confidence" ]]; then
        log_and_exit 1 "failed to decide"
    fi

    echo
    ls -l "${old_md}" "${new_md}"
    printf '\n⚖️  Verdict: %s (confidence %s)\n\n' "$choice" "$confidence"

    if awk "BEGIN{exit !($confidence < 0.80)}"; then
        printf '  ⚠ low confidence, defaulting to .odd\n'
        choice="NEITHER"
    fi

    case "$choice" in
        NEW)       mv_ "${new_md}" "${old_md}" ;;
        OLD)       mv_ "${new_md}" "${new_md}.reject" ;;
        IDENTICAL) mv_ "${new_md}" "${new_md}.reject" ;;
        NEITHER)   mv_ "${new_md}" "${new_md}.reject" ;;
        *)         mv_ "${new_md}" "${new_md}.odd" ;;
    esac

    printf '\n== End %s → %s: %s ==\n' "$old_md" "${new_md}" "$choice"
done
