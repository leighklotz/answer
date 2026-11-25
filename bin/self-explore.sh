#!/usr/bin/env -S bash -e
set -o pipefail

source ~/wip/answer/bin/commands/hx-bootstrap.sh && hx core
source ~/wip/answer/bin/env.sh
source ~/wip/answer/bin/logging.sh

export INFO=1

mdl="$(hx model)"
mdl="${mdl/\//_}"

# round n
function round {
    local round="$1"; shift
    local previous_input_file="$1"; shift
    local prompt_template='Your source code is two git repos named `answer` and `toolex`.
The current pipeline running is `'"$0"'`.
Rounds: This is round %d and you are exploring %s. You cannot access other repos, but you can output whatever you need for round 2 in round 1. Round 2 will receive the output of round 1.
Goal: Read the python and bash code and give an assessment of the harness.
Restrictions:
    - Generally `bin/foo` is a symlink to `bin/foo.sh`.
    - Before believing for `docs/` and `tests/`, check the date for staleness wrt to commits.
    - Tokens are limited so exercise care when using `find` and other multi-file operations.
    - Minishell does not accept semicolon command separators.
    - IMPORTANT: Stay out of `.gitignore`-d files and dirs.
    - IMPORTANT: Stay out of any `.hallux/` directory. They contain many large temp files of indescribable provenance.
    - IMPORTANT: Focus primarily on current source code and use git sparingly to resolve questions.
    - IMPORTANT: DO NOT CHANGE ANYTHING.
'
    local prompt
    printf -v prompt "$prompt_template" "$round" "$(pwd)"
    (bx cat -n HALLUX.md; bx cat README.md; bx ls -l; bx cat "$previous_input_file")  | ask "$prompt" | tools git minishell:read --total-iterations=60
}

d="${HOME}/wip/answer/.hallux/self-explore-${mdl}-$$"
mkdir -p "$d"
round_1_out="$d/round-1.md"
round_2_out="$d/round-2.md"

log_info "Round 1"
cd "$HOME/wip/answer"
round 1 /dev/null | answer > "$round_1_out"
echo >&2
log_info "$round_1_out"         # print the fn now in case round 2 fails

log_info "Round 2"
cd "$HOME/wip/toolex"
round 2 "$round_1_out" | answer > "$round_2_out"
echo >&2
log_info "$round_1_out"
log_info "$round_2_out"
