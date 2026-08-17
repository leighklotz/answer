# bootstrap hx
# enable function only; once enabled, answer will override
function hx () {
  local arg="$1"
  [[ "${BASH_VERSINFO[0]}" -lt 4 ]] && { echo "ERROR: bash 4+ required." >&2; return 1; }
  case "$arg" in
    "") hx enable && echo -n "🦣hallux enabled: model=" && hx model ;;
    "enable") source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/bin/commands/enable" ;;
    *) echo "usage: hx [enable]" >&2; return 1 ;;
  esac
}
