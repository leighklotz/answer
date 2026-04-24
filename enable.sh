# enable.sh: source this file

[[ ":$PATH:" != *":$HOME/wip/answer:"* ]] && export PATH="$HOME/wip/answer:$PATH"

if [[ "$PS1" != *"🦶"* ]]; then
    export ANSWER_OLD_PS1="$PS1"
    [[ "$PS1" == *'$'* ]] && PS1="${PS1/\\$/🦶\\$}" || PS1="🦶${PS1}"
fi

source ~/wip/answer/functions.sh
