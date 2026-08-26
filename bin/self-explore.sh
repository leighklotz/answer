#!/bin/bash

source ~/wip/answer/bin/commands/hx-bootstrap.sh && hx enable
mdl="$(hx model)"

ask 'This is you: ~/wip/answer and ~/wip/toolex/. Feel free to explore. Stay out of .gitignore-d files and dirs in both projects. Read the python and bash code and give an assessment of the harness.' |
    tools file:read_anywhere bash git | answer -t > ~/wip/answer/.hallux/self-explore-$$-"$mdl"
