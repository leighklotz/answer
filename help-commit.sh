#!/usr/bin/env bash

SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE}")")"
source "${SCRIPT_DIR}/functions.sh"

GIT_COMMIT_PROMPT="Below is the output of a git bash session.  Read the session and then briefly output a code fence containing a corresponding \`git commit\` command, using using one or more bash git commands as appropriate for the change. Use conventional commits. For commits that are not single-focus, give more descriptive messages. If you do not have enough information to write a commit message and need to see more git results, output a brief request concluding with a code fence containing one or more bash git commands to execute to obtain the results. \n"

# TODO pipetest needs to present only the human-readable last conversion but send on the whole convo
# or should it take only code? or should we skill unfence to prompt instead that?
# `pipetest | answer` or `answer | pipetest` or `unfence --ask`
# much confusion about whether each these should accept/produce json or text

# (bx git status; bx git diff --numstat; bx git diff; git diff --cached) | ask -i "${GIT_COMMIT_PROMPT}" |  pipetest | answer | unfence | bash
# (bx git status; bx git diff --numstat; bx git diff; git diff --cached) | ask -i "${GIT_COMMIT_PROMPT}" |  answer | pipetest | unfence | bash
# (bx git status; bx git diff --numstat; bx git diff; git diff --cached) | ask -i "${GIT_COMMIT_PROMPT}" |  answer | unfence --ask | bash

(bx git status; bx git diff --numstat; bx git diff; git diff --cached) | ask -i "${GIT_COMMIT_PROMPT}" |  answer | pipetest | unfence | bash

