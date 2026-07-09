# bootstrap hx
# enable function only; once enabled, answer will override
function hx () {
    if [ "${BASH_VERSINFO[0]}" -lt 4 ]; then
        echo "🦶ERROR: bash 4+ required (BASH_VERSION=${BASH_VERSION})." >&2
        return 1 2>/dev/null
    fi
    if  [ "$1" == "enable" ]; then
        source ~/wip/answer/bin/commands/enable
    else
        echo "usage: hx enable"
        return 1
    fi
}


