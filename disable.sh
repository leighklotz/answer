# disable.sh: source this file

export PATH=$(echo "$PATH" | sed -e "s|:$HOME/wip/answer:|:|g" \
                               -e "s|^$HOME/wip/answer:||" \
                               -e "s|:$HOME/wip/answer$||" \
                               -e 's|::|:|g')

if [ -n "${ANSWER_OLD_PS1}" ]; then
    export PS1="${ANSWER_OLD_PS1}"
    unset ANSWER_OLD_PS1
elif [[ "$PS1" == *"🦶"* ]]; then
    echo "🦶: failed to disable"
fi
