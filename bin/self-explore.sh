#!/usr/bin/env -S bash -e

source ~/wip/answer/bin/commands/hx-bootstrap.sh && hx core
source ~/wip/answer/bin/env.sh
source ~/wip/answer/bin/logging.sh

export INFO=1

mdl="$(hx model)"
mdl="${mdl/\//_}"

# round n
function round {
    local round="$1"; shift
    local prompt_template='This is your source code: `~/wip/answer` and `~/wip/toolex/`. 
The current pipeline running is `'"$0"'`.
Rounds: This is round %d. Round 1 explores `answer/` and round 2 explores `toolex/`. You cannot cross-access but you can output whatever you need for round 2 in round 1.
Goal: Read the python and bash code and give an assessment of the harness.
Restrictions:
    - Generally `bin/foo` is a symlink to `bin/foo.sh`.
    - Before believing for `docs/` and `tests/`, check the date for staleness wrt to commits.
    - Tokens are limited so exercise care when using `find` and other multi-file operations.
    - Minishell does not accept semicolon command separators.
    - IMPORTANT: Stay out of `.gitignore`-d files and dirs.
    - IMPORTANT: Stay out of `.hallux/` directory. It contains many large temp files of indescribable provenance.
    - IMPORTANT: Focus primarily on current source code and use git sparingly to resolve questions.
    - IMPORTANT: DO NOT CHANGE ANYTHING.
'
    printf -v prompt "$prompt_template" "$round"
    (bx cat -n HALLUX.md; bx cat README.md; bx ls -l)  | ask "$prompt" | tools git minishell:read --total-iterations=60
}

d="${HOME}/wip/answer/.hallux/self-explore"
mkdir -p "$d"
round_1_out="$d/round-1-$$-${mdl}"
round_2_out="$d/round-2-$$-${mdl}"

log_info "Round 1"
cd $HOME/wip/answer
round 1 | answer > "$round_1_out"
echo >&2
log_info "$round_1_out"

log_info "Round 2"
cd $HOME/wip/toolex
cat "$round_1_out" | round 2 | answer > "$round_2_out"
echo >&2
log_info "$round_1_out"
log_info "$round_2_out"
