#!/bin/bash

SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE}")")"
CAPTURE_COMMAND="cat"
FETCHER_COMMAND="${SCRIPT_DIR}/fetcher.sh"

# Requires snap/golang yq for yaml->json, and regular jq to extract
source "${SCRIPT_DIR}/commands/enable"
source "${SCRIPT_DIR}/logging.sh"

OUTPUT_MODE='LINK'

# expecting something like /snap/bin/yq
# yq (https://github.com/mikefarah/yq) version v4.49.2
# log_info "yq=$(which yq)"
# log_info "jq=$(which jq)"

while true; do
    case "$1" in
        "--help")
            usage "HELP"
            exit 1
            ;;
        "--link")
            OUTPUT_MODE='LINK'
            shift
            ;;
        "--yaml")
            OUTPUT_MODE='YAML'
            shift
            ;;
        "--capture-file")
            shift
            printf -v CAPTURE_COMMAND "tee %b" "$1"
            shift
            ;;
        *)
            LINK="$1"
            shift
            ARGS="$*"
            break
            ;;
    esac
done

if [ -z "$LINK" ]; then
    usage "NOLINK"
fi

function extract_output() {
    case "$OUTPUT_MODE" in
        "YAML")
            cat
            ;;
        "LINK")
            to_link
            ;;
        *)
            usage "BAD OUTPUT_MODE=$OUTPUT_MODE"
            ;;
    esac
}

function to_link() {
    # <https://scuttle.klotz.me/bookmarks/klotz?action=add&address=https://example.com&title=Example+Website+&description=This+is+an+example+website&tags=example,website,canonical+page>
    jq_filter='
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
  + "&address="     + (.link        | formenc)
  + "&description=" + (.description | formenc)
  + "&title="       + (.title       | formenc)
  + "&tags="        + (csv_tags     | formenc)
'
  yq -r '.' -o=json | jq -r "$jq_filter"
}

function capture() {
    if [[ $? -ne 0 ]]; then
        log_and_exit "$?" "$(cat)"
    fi
  ${CAPTURE_COMMAND}
}

# remove smart quotes, as they cause parsing errors
function replace_smart_quotes() {
    sed -e 's/[“”]/"/g'
}

SCUTTLE_PROMPT='# Instructions
Summarize the article in one brief paragraph followed by a a blank line and then few terse bullet points which add interesting or important information not already included in the paragraph. If there is an ident8fied author, begin the summary with "<author name> writes".

- Diction: "utilize" means to make use of something for other than its intended purpose
- Reserve "AI" for research beyond LLMs.

YAML output format:
- If the page loaded normally, respond with only a YAML file with these 4 fields: \`link\`, \`title\`, \`description\`, and \`keywords\` array.
- For the \`description\` field, use the YAML literal block scalar format (starting with the \`|\` symbol).
- Put quotes around the `title`.
- Do NOT put quotes around the block scalar content.
- If there are retrieval failures, failed JavaScript, or Captcha challenges, just report on the failures in YAML using \`link\` and \`error\` fields.
- Use YAML block scalar for error.

In success case, output in exact this YAML format:
link: ...
title: "..."
description: |
...
keywords:
  - ...
  - ..

In failure case, output in exact this YAML format:
link: ...
error: ...
'

(
    printf "# Text of link %s\n\n---\n\n%s\n" "${LINK}" "${SCUTTLE_PROMPT}";
    "${FETCHER_COMMAND}" "${LINK}" | ${CAPTURE_COMMAND};
    printf "%b\n" "${SCUTTLE_PROMPT}"
) |
    ask ${ARGS} -- "${SCUTTLE_PROMPT}" | answer | replace_smart_quotes | extract_output
