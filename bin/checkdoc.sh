#!/usr/bin/env -S bash
shopt -s nullglob
set -o pipefail

SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE}")")"
source "${SCRIPT_DIR}/logging.sh"
CMD_DIR="${SCRIPT_DIR}/../doc/commands"

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
    base="${new_md%.new}"                                   # foo.md
    checkdoc_out="${output_dir}/checkdoc-${base}"           # checkdoc-foo.md

    echo "=== Analysis of $old_md -> ${new_md} in ${checkdoc_out} ===" > "$checkdoc_out"

    # Perform the AI analysis and append to the freshly created file.
    # We use '>' (via tee) above to ensure we are not appending new results 
    # onto old/stale comparison text from previous failed runs.
    if ! dreck "${old_md}" "${new_md}" | answer -m >> "$checkdoc_out"; then
        log_and_exit 1 "Analysis pipeline failed for ${old_md} --> ${new_md}"
    fi

    # We now prompt the user. Because we just re-ran dreck, 
    # < "$checkdoc_out" is guaranteed to contain current comparison data.
    verdict="$(ask "Sum up in one word: NEW, OLD, IDENTICAL, NEITHER. " < "$checkdoc_out" | answer)"
    
    echo
    ls -l "${old_md}" "${new_md}"
    printf "\n⚖️ Verdict: %s\n" "${verdict}"
    printf "\n"

    case "${verdict}" in
        *NEW*)
            # The AI suggests the new file is actually the correct/newer version of the old one.
            printf '```bash\nmv "%s" "%s"\n```\n' "${new_md}" "${old_md}" | unfence bash | bash
            ;;
        *OLD*)
            # The AI suggests the new file is an outdated or rejected version.
            printf '```bash\nmv "%s" "%s"\n```\n' "${new_md}" "${new_md}.reject"  | unfence bash | bash
            ;;
        *IDENTICAL*)
            # No changes needed; remove the temporary .new file.
            printf '```bash\nrm "%s"\n```\n' "$new_md" | unfence bash | bash
            ;;
        *NEITHER*|*)
            # The AI suggests it is neither a simple update nor an identical copy (it's "odd").
            printf '```bash\nmv "%s" "%s"\n```\n' "${new_md}" "${new_md}.odd"  | unfence bash | bash
            ;;
    esac

    printf "\n== End Analysis %s -> %s: %s ==\n" "$old_md" "$new_md" "$verdict"
done
