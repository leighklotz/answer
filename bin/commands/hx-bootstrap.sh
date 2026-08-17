# bootstrap hx
# enable function only; once enabled, answer will override

HX_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../" && pwd -P)"

function hx () {
  local arg="$1"

  [[ "${BASH_VERSINFO[0]}" -lt 4 ]] && {
    echo "ERROR: bash 4+ required." >&2
    return 1
  }

  case "$arg" in
    enable|"") hx PS1 && hx core && echo -n "👣 hallux enabled: model=" && hx model ;;
    core) source "$HX_ROOT/bin/commands/enable-core.sh" ;;
    PS1) source "$HX_ROOT/bin/commands/PS1.sh" ;;
    *)        echo "usage: hx [\"\"|enable|core|PS1]" >&2; return 1 ;;
  esac
}
