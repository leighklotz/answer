#!/usr/bin/env -S bash -e

SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE}")")"
source "${SCRIPT_DIR}/env.sh"
source "${SCRIPT_DIR}/logging.sh"
source "${SCRIPT_DIR}/functions.sh"

PROMPT="Perform a rigorous comparison between these two files. 0) if the file is JSON, empty, binary data, etc. report that fact and stop immediately. 1) Detect any 'LLM dreck' in the second file (unnecessary conversational intro/outro or boilerplate). 2) Check for lazy elisions—ensure no critical content from the first file was omitted, summarized away, or truncated in the second version. 3) Conclude if the changes represent a substantive improvement in quality and completeness."

# TODO:
# `- dreck fn1 fn2` # as current, compares fn1 and fn2 with lx
# `- dreck fn1 fn21 -- "more prompt words" words words` # same as above but prompt words appended to PROMPT as USER_PROMPT
# `- dreck # as current, compares two entities on input (lx output, git diff output, etc)
# `- dreck -- "more prompt words" words words` # are words appended to PROMPT as USER_PROMPT

USER_PROMPT=""

if [[ -n "$1" ]] && [[ -n "$2" ]]; then
    if cmp --quiet "$1" "$2"; then
        ask "echo 'files are identical'" 
        exit 0
    fi
    lx "$1" "$2" | ask "$@" "${PROMPT}" "${USER_PROMPT}"
else
    ask "$@" "${PROMPT}"
fi
