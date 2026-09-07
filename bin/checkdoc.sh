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
  base="${new_md%.new}"                                   # foo.md
  checkdoc_out="${output_dir}/checkdoc-${base}"           # checkdoc-foo.md
  [[ ! -f "$old_md" ]] && log_warn "$old_md does not exist"
  [[ -e "$checkdoc_out" ]] && log_warn "$checkdoc_out already exists"
done

for new_md in *.md.new
do
  old_md="${new_md%.new}"
  base="${new_md%.new}"                                   # foo.md
  checkdoc_out="${output_dir}/checkdoc-${base}"           # checkdoc-foo.md
  [[ ! -f "$old_md" ]] && log_and_exit 1 "$old_md does not exist"
  echo "=== Analysis of $old_md -> ${new_md} in ${checkdoc_out} ===" | tee "$checkdoc_out"
  if ! [[ -e "$checkdoc_out" ]]; then
     if ! dreck "${old_md}" "${new_md}" | answer -m >> "$checkdoc_out"; then
	 log_and_exit 1 "analysis pipeline failed for ${old_md} --> ${new_md}"
     fi
  fi
  verdict="$(ask "Sum up in one line: NEW, OLD, IDENTICAL, NEITHER" < "$checkdoc_out" | answer)"
  printf "\n"
  printf "Verdict: %s\n" "${verdict}"
  printf "\n"
  case "${verdict}" in
      *NEW*)
	  printf '```bash\nmv "%s" "%s"\n```\n' "${new_md}" "${old_md}"  | unfence bash | bash
	  ;;
      *OLD*)
	  printf '```bash\nmv "%s" "%s"\n```\n' "${new_md}" "${new_md}.reject"  | unfence bash | bash
	  ;;
      *IDENTICAL*)
	  printf '```bash\nrm "%s"\n```\n' "$new_md" | unfence bash | bash
	  ;;
      *NEITHER*|*)
	  printf '```bash\nmv "%s" "%s"\n```\n' "${new_md}" "${new_md}.odd"  | unfence bash | bash
	  ;;
  esac
  printf "\n== End Analysis %s -> %s: %s\n" "$old_md" "$new_md" "$verdict"
done
