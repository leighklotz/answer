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
    "")       hx enable && echo -n "👣 hallux enabled: model=" && hx model ;;
    "enable") source "$HX_ROOT/bin/commands/enable.sh" ;;
    *)        echo "usage: hx [enable]" >&2; return 1 ;;
  esac
}
