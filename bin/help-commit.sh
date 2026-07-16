#!/usr/bin/env bash 

set -o pipefail
SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE}")")"
source "${SCRIPT_DIR}/env.sh"
source "${SCRIPT_DIR}/logging.sh"
source "${SCRIPT_DIR}/functions.sh"

#GIT_COMMIT_PROMPT="Below is the output of a git bash session.  Read the session and then briefly output a code fence containing a corresponding \`git commit\` command, using using one or more bash git commands as appropriate for the change. Use conventional commits. For commits that are not single-focus, give more descriptive messages. Be specific in filenames: avoid 'git add .' and the like. Note working directory before using relative filenames. Use multiple separate commits if changes are truly independent.\n"

GIT_COMMIT_PROMPT='Below is the output of a git bash session.  Read the session. Generate a bash code fence to commit all staged and unstaged changes (ignore untracked). 
If no changes exist, output `echo "no changes"`. Otherwise, use one or more commands of this exact format:

git commit -a \
  -m "<Brief summary of impact>" \
  -m "- <Imperative description of change 1>" \
  -m "- <Imperative description of change 2>"

Rules:
- Use imperative mood (e.g., "Add feature" not "Added feature").
- Ensure all strings are properly quoted.
- No commentary after the code fence.
- Properly escape special characters inside bash quotes.'


# GIT_COMMIT_TOOL_PROMPT="Below is the output of a git bash session.  Read the session and then briefly output a code fence containing a corresponding \`git commit\` command, using using one or more bash git commands as appropriate for the change. Use conventional commits. For commits that are not single-focus, give more descriptive messages. If you do not have enough information to write a commit message and need to see more git results, output a brief request concluding with a code fence containing one or more bash git commands to execute to obtain the results. Note working directory before using relative filenames.\n"

# TODO pipetest needs to present only the human-readable last conversion but send on the whole convo
# or should it take only code? or should we skill unfence to prompt instead that?
# `pipetest | answer` or `answer | pipetest` or `unfence --ask`
# much confusion about whether each these should accept/produce json or text

if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
    echo "🦶$(basename "$0"): PWD=$PWD is not in a git repository"
    exit 1
fi

function usage() {
    local p=$(basename "$0")
    echo "$p: [--help] | [--quiet] [git diff options] [--] [ask options]"
    echo $'- --quiet: suppress introductory message'
    echo $'- any next arguments until `--` are given to `git diff`'
    echo $'- all after a `--` is given as parameters to `ask`'
}


GIT_DIFF_OPTIONS=""

# help-commit [git diff options] -- [help options]
while [[ $# -gt 0 ]]; do
    case $1 in
        --help)
            usage
            exit 1
            ;;
        --quiet|-q)
            QUIET=1
            shift
            ;;
        --)
            shift
            ASK_OPTIONS=("$@")
            break
            ;;
        *)
            GIT_DIFF_OPTIONS+="${1} "
            shift
            ;;
    esac
done

# options are sent bare on the line since there can be multiple options
# ASK_OPTIONS is an array but GIT_DIFF_OPTIONS is built up word by word
log_info "ASK_OPTIONS=${ASK_OPTIONS[*]}"
log_info "GIT_DIFF_OPTIONS=$GIT_DIFF_OPTIONS"

(bx pwd;
 bx git rev-parse --show-toplevel;
 git diff --stat --no-merges ${GIT_DIFF_OPTIONS};
 bx git diff --numstat ${GIT_DIFF_OPTIONS};
 bx git diff ${GIT_DIFF_OPTIONS};
 bx git diff --cached ${GIT_DIFF_OPTIONS}) |
  ask -i "${ASK_OPTIONS[@]}" -- "${GIT_COMMIT_PROMPT}" |
  answer |
  unfence |
  bash

# Capture the exit status of the last command in the pipe (thanks to pipefail)
STATUS=$?

if [ $STATUS -eq 2 ]; then
    # code 2 means 'unfence' found no blocks, or perhaps bash did (!)
    log_warn "No changes"
    exit 0
fi

# If it was anything else, exit with that status (error or success)
exit $STATUS
