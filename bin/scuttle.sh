#!/usr/bin/env bash
set -Eeuo pipefail
set -o errtrace

SCRIPT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CAPTURE_COMMAND=(cat)
FETCHER_COMMAND=("${SCRIPT_DIR}/fetcher.sh")

source "${SCRIPT_DIR}/commands/enable"
source "${SCRIPT_DIR}/logging.sh"

trap 'log_error "error in ${BASH_SOURCE[1]}:${BASH_LINENO[0]} while running: ${BASH_COMMAND}"' ERR

# Requires snap/golang yq for yaml->json, and regular jq to extract
command -v yq >/dev/null || { log_and_exit 1 "yq missing"; }
command -v jq >/dev/null || { log_and_exit 1 "jq missing"; }
[[ -x "${FETCHER_COMMAND[0]}" ]] || { log_and_exit 1 "fetcher missing"; }

CAPTURE_FILE=''
OUTPUT_MODE='LINK'
ASK_EXTRA_ARGS=()

function usage() {
    local uu="$1"
    printf 'usage: %s [--yaml|--link] [--capture-file FILE] <link> [ask args...]\nerror: %s\n' \
      "$(basename "$0")" "$uu" >&2
    exit 1
}

# expecting something like /snap/bin/yq
# yq (https://github.com/mikefarah/yq) version v4.49.2
# log_info "yq=$(which yq)"
# log_info "jq=$(which jq)"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --help) usage "HELP"; exit 1 ;;
    --link) OUTPUT_MODE='LINK'; shift ;;
    --yaml) OUTPUT_MODE='YAML'; shift ;;
    --capture-file)
      [[ $# -ge 2 ]] || usage "BAD CAPTURE FILE"
      CAPTURE_FILE="$2"
      dir=$(dirname -- "$CAPTURE_FILE")
      [[ -d "$dir" && -w "$dir" ]] || usage "BAD CAPTURE FILE DIRECTORY"
      [[ -e "$CAPTURE_FILE" ]] && [[ ! -w "$CAPTURE_FILE" ]] && usage "UNWRITABLE CAPTURE FILE"
      CAPTURE_COMMAND=(tee "$CAPTURE_FILE")
      shift 2
      ;;
    *) 
      LINK="$1"
      shift
      ASK_EXTRA_ARGS=("$@")
      break
      ;;
  esac
done

[[ -z "${LINK:-}" ]] && usage "NOLINK"
[[ "${LINK}" =~ ^https?:// ]] || usage "BAD LINK"

function extract_output() {
    case "$OUTPUT_MODE" in
        YAML) cat ;;
        LINK) to_link ;;
        *) usage "BAD OUTPUT_MODE=$OUTPUT_MODE" ;;
    esac
}

function to_link() {
    # <https://scuttle.klotz.me/bookmarks/klotz?action=add&address=https://example.com&title=Example+Website+&description=This+is+an+example+website&tags=example,website,canonical+page>
    local jq_filter
    read -r -d '' jq_filter << 'EOF'
def formenc:
  @uri
  | gsub("%20"; "+")
  | gsub("%2C"; ",");

def csv_tags:
  if .keywords == null then ""
  elif (.keywords | type) == "array" then (.keywords | join(","))
  else .keywords
  end;

"https://scuttle.klotz.me/bookmarks/klotz?action=add"
  + "&address="     + ((.link        // "") | formenc)
  + "&description=" + ((.description // "") | formenc)
  + "&title="       + ((.title       // "") | formenc)
  + "&tags="        + (csv_tags | formenc)
'EOF'
  yq -o=json -I0 '.' | jq -r "$jq_filter"
}

# remove smart quotes, as they cause parsing errors
function replace_smart_quotes() {
    sed -e "s/[‘’]/\'/g" -e "s/[“”‟]/\"/g" -e "s/[‚„]/,/g" -e "s/[‛]/\`/g"
}

read -r -d '' SCUTTLE_PROMPT << 'EOF'
# Instructions
Summarize the article in one brief paragraph followed by a blank line and then a few terse bullet points marked with `-` that add interesting or important information not already included in the paragraph. If there is an identified author, begin the summary with "<author name> writes".

- Diction: "utilize" means to make use of something for other than its intended purpose
- Reserve "AI" for research beyond LLMs.

YAML output format:
- If the page loaded normally, respond with only a YAML file with these 4 fields: `link`, `title`, `description`, and `keywords` array.
- DO Put quotes around the `title`.
- Use YAML block scalar for `description` and `error` fields. Indent every line of the block scalar by two spaces. DO NOT put quotes around the block scalar content.

In success case, output in exact this YAML format:

link: ...
title: "..."
description: |
  ...
keywords:
  - ...
  - ..

If there are retrieval failures, failed JavaScript, or Captcha challenges, just report on the failures in YAML using `link` and `error` fields:

link: ...
error: |
  ..
EOF

{
    printf 'Text of link %s\n\n---\n\n' "$LINK"
    "${FETCHER_COMMAND[@]}" "$LINK" | "${CAPTURE_COMMAND[@]}"
} |
    ask "${ASK_EXTRA_ARGS[@]}" -- "${SCUTTLE_PROMPT}" | answer | replace_smart_quotes | extract_output
