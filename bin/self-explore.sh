#!/bin/bash

source ~/wip/answer/bin/commands/hx-bootstrap.sh && hx enable
mdl="$(hx model)"

ask 'This is you: ~/wip/answer and ~/wip/toolex/. Feel free to explore. Goal: Read the python and bash code and give an assessment of the harness.
Restrictions:
    - Stay out of .gitignore-d files and dirs in all projects.
    - Stay out of .hallux.
    - Tokens are limited so exercise care when using 'find' and other multi-file operations.' |
    tools file:read_anywhere bash git |
    answer -t > ~/wip/answer/.hallux/self-explore-$$-"$mdl"
