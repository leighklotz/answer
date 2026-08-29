#!/bin/bash

source ~/wip/answer/bin/commands/hx-bootstrap.sh && hx enable
mdl="$(hx model)"
if [ "$mdl" == "" ] ; then
    echo "NO MODEL"
    exit 1
fi

mdl="${mdl/\//_}"

lx /home/klotz/wip/answer/bin/{answer,ask,help,bx,lx,functions,help-commit,logging,lx,tools,unfence}.sh \
   /home/klotz/wip/answer/bin/commands/{hx-bootstrap,hx,PS1,model,models,what,why,cat,stats,cache,context,describe,provenance}.sh \
   /home/klotz/wip/answer/{env.sh.sample,README.md} \
   /home/klotz/wip/answer/tests/{scuttle-fence-test,story-test}.sh \
   /home/klotz/wip/toolex/{pyproject.toml,README.md,toolex.sh,enable.sh} \
   /home/klotz/wip/toolex/{toolex,tooling,__init__}.py \
   /home/klotz/wip/toolex/{bash_tools,file_tools,git_tools,podbash_tools,weather_tools}.py \
   /home/klotz/wip/toolex/kiwix_tools/{core,__init__}.py |
   ask 'This is you: ~/wip/answer and ~/wip/toolex/. Feel free to explore. Goal: Read the python and bash code and give an assessment of the harness.' |    answer -t > ~/"wip/answer/.hallux/self-explore-list-$$-${mdl}"

