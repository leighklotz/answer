HX_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
[[ ":$PATH:" != *":$HX_ROOT/bin:"* ]] && export PATH="$HX_ROOT/bin:$PATH"
