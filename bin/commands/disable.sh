# disable.sh: source this file

export PATH=$(echo "$PATH" | sed -e "s|:$HOME/wip/answer/bin:|:|g" \
                                 -e "s|^$HOME/wip/answer/bin:||" \
                                 -e "s|:$HOME/wip/answer/bin$||" \
                                 -e 's|::|:|g')

if [ -n "${HX_OLD_PS1}" ]; then
    export PS1="${HX_OLD_PS1}"
    unset HX_OLD_PS1
elif [[ "$PS1" == *"👣"* ]]; then
    echo "👣: failed to disable"
fi

echo "👣 answer removed from path but functions remain defined"
