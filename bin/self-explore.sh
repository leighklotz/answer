#!/bin/bash

source ~/wip/answer/bin/commands/hx-bootstrap.sh && hx enable
mdl="$(hx model)"
mdl="${mdl/\//_}"

ask 'This is you: `~/wip/answer` and `~/wip/toolex/`. Feel free to explore. Goal: Read the python and bash code and give an assessment of the harness.
See `answer/HALLUX.md` for introductions; `toolex/HALLUX.md` is a symlink to it.
Restrictions:
    - DO NOT CHANGE ANYTHING.
    - Stay out of .gitignore-d files and dirs in all projects.
    - Stay out of .hallux.
    - Generally `bin/foo` is a symlink to `bin/foo.sh`.
    - Especially for doc and tests, check the date.
    - Tokens are limited so exercise care when using 'find' and other multi-file operations.
    - Due to context limits, Explore answer first. Look in toolex only for specific questions.
' |
    tools \
        git \
        minishell:read_anywhere=$HOME/wip/answer,$HOME/wip/answer/\* \
        minishell:read_anywhere=$HOME/wip/toolex,$HOME/wip/toolex/\* \
        --drop-tool-reasoning |
answer -t > ~/wip/answer/.hallux/self-explore-$$-"$mdl"

#        file:read_anywhere=$HOME/wip/answer/\*,$HOME/wip/toolex/\* 
#        file:read_anywhere=$HOME/wip/answer,$HOME/wip/toolex 

