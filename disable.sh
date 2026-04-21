# disable.sh
export PATH="${PATH#$HOME/wip/answer:}"
if [ -z "${ANSWER_OLD_PS1}" ]; then
    export PS1="${ANSWER_OLD_PS1}"
    unset ANSWER_OLD_PS1
fi

