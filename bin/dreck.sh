#!/usr/bin/env -S bash -e

SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE}")")"
source "${SCRIPT_DIR}/env.sh"
source "${SCRIPT_DIR}/logging.sh"
source "${SCRIPT_DIR}/functions.sh"

PROMPT="Perform a rigorous comparison between these two files. 1) Detect any 'LLM dreck' in the second file (unnecessary conversational intro/outro or boilerplate). 2) Check for lazy elisions—ensure no critical content from the first file was omitted, summarized away, or truncated in the second version. 3) Conclude if the changes represent a substantive improvement in quality and completeness."

ask "$@" "${PROMPT}"

