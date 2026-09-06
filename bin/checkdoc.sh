#!/usr/bin/env -S bash -u
shopt -s nullglob
set -o pipefail

SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE}")")"
source "${SCRIPT_DIR}/logging.sh"
CMD_DIR="${SCRIPT_DIR}/../doc/commands"

output_dir="$(realpath "${1:-}")"

cd "${CMD_DIR}" || log_and_exit 1 "${CMD_DIR} does not exist"

if [ ! -n "$output_dir" ]; then
    echo "usage; $0 output-dir"
    exit 1
fi

for new_md in *.md.new
do
  old_md="${new_md%.new}"
  checkdoc_out="${output_dir}/checkdoc-${new_md}"
  [[ ! -f "$old_md" ]] && log_warn "$old_md does not exist"
  [[ -e "$checkdoc_out" ]] && log_warn "$checkdoc_out already exists"
done

for new_md in *.md.new
do
  old_md="${new_md%.new}"
  checkdoc_out="${output_dir}/checkdoc-${new_md}"
  [[ ! -f "$old_md" ]] && log_and_exit 1 "$old_md does not exist"
  echo "=== Analysis of $old_md -> ${new_md} in ${checkdoc_out} ===" | tee "$checkdoc_out"
  if ! [[ -e "$checkdoc_out" ]]; then
     if ! dreck "${old_md}" "${new_md}" | answer -m >> "$checkdoc_out"; then
	 log_and_exit 1 "analysis pipeline failed for ${old_md} --> ${new_md}"
     fi
  fi
  verdict="$(ask "summarize in one line, nothing else: NEW, OLD, IDENTICAL, NEITHER" < "$checkdoc_out" | answer)"
  echo "== End Analysis ${old_md} -> ${new_md} in ${checkdoc_out}: ${verdict} ==="
  echo
done
