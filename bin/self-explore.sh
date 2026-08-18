#!/bin/bash
hx enable
hx model
ask 'This is you: ~/wip/answer and ~/wip/toolex/. Feel free to explore. Stay out of .gitignore-d files and dirs in both projects. Read the python and bash code and give me an assessment of the harness.' |
    tools file:read_anywhere bash git
