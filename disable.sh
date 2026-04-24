# disable.sh: source this file
export PATH="${PATH#$HOME/wip/answer:}"
if [ -n "${ANSWER_OLD_PS1}" ]; then
    export PS1="${ANSWER_OLD_PS1}"
    unset ANSWER_OLD_PS1
elif [[ "${PS1}" =~ "🦶" ]]; then
    echo "🦶: failed to disable"
fi
