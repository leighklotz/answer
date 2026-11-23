#!/bin/bash

source ~/wip/answer/bin/commands/hx-bootstrap.sh && hx enable
source ~/wip/answer/bin/env.sh
source ~/wip/answer/bin/logging.sh

mdl="$(hx model)"
mdl="${mdl/\//_}"

# dir
function cap_read_dir {
    local dir="$1"
    local cap=""
    if [[ "$dir" == "$PWD" ]]; then
        printf -v cap "minishell:read"
    else
        printf -v cap "minishell:read_anywhere=%s" "$dir"
    fi
    if [[ -n "$cap" ]]; then
        log_info "$cap"
        printf "%s" "$cap"
    fi
}
    
# round n cap
function round {
    local round="$1"; shift
    local capabilities="$1"
    local prompt_template='This is you: `~/wip/answer` and `~/wip/toolex/`. Feel free to explore them individually in two rounds. 
Round: This is round %d.
Goal: Read the python and bash code and give an assessment of the harness.
Resources: Use provided tools to read `answer/HALLUX.md` or `toolex/HALLUX.MD` for introductions; they are identical.
Restrictions:
    - DO NOT CHANGE ANYTHING.
    - Stay out of .gitignore-d files and dirs in all projects.
    - Stay out of `.hallux/`.
    - Generally `bin/foo` is a symlink to `bin/foo.sh`.
    - Before believing for `docs/` and `tests/`, check the date for staleness wrt to commits.
    - Tokens are limited so exercise care when using `find` and other multi-file operations.
    - Due to context limits, Explore answer first. Look in toolex only for specific questions.
    - Round 2 gets the output of Round 1.
'
    printf -v prompt "$prompt_template" "$round" | ask "$prompt" | tools git "$capabilities" --drop-tool-reasoning
}

d="${HOME}/wip/answer/.hallux/self-explore"
mkdir -p "$d"
round_1_out="$d/round-1-$$-${mdl}"
round_2_out="$d/round-2-$$-${mdl}"

log_info "Round 1"
ask "$(round 1 "$(cap_read_dir "$HOME/wip/answer")")" | answer > "$round_1_out"

log_info "Round 2"
cat "$round_1_out" | ask "$(round 2 "$(cap_read_dir "$HOME/wip/toolex")")" | answer > "$round_2_out"

echo "$round_1_out"
echo "$round_2_out"
