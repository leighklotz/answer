#!/usr/bin/env -S bash -u
shopt -s nullglob
set -o pipefail

SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE}")")"
source "${SCRIPT_DIR}/logging.sh"
CMD_DIR="${SCRIPT_DIR}/../doc/commands"

cd "${CMD_DIR}" || log_and_exit 1 "${CMD_DIR} does not exist"

for new_file in *.md.new
do
  old_md="${new_file%.new}"
  out_file="checkdoc-${new_file}"
  [[ ! -f "$old_md" ]] && log_warn "$old_md does not exist"
  [[ -e "$out_file" ]] && log_warn "$out_file already exists"
done

for new_file in *.md.new
do
  old_md="${new_file%.new}"
  out_file="checkdoc-${new_file}"
  [[ ! -f "$old_md" ]] && log_and_exit 1 "$old_md does not exist"
  [[ -e "$out_file" ]] && log_and_exit 1 "$out_file already exists"
  echo "=== Analysis of $old_md -> ${new_file} in ${out_file} ===" | tee "$out_file"
  if ! lx "$old_md" "${new_file}" | dreck | answer -m >> "$out_file"; then
    log_and_exit 1 "analysis pipeline failed for ${old_md} --> ${new_file}"
  fi
  # just for show
  echo "== End Analysis ${old_md} -> ${new_file} in ${out_file} ==="
  echo
done
