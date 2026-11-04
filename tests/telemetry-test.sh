#!/usr/bin/env bash
# Unit test for emit_telemetry (no LLM/API required). Needs python3, jq, and socat or nc.
set -u
ROOT="$(dirname "$(dirname "$(realpath "${BASH_SOURCE[0]}")")")"
TMP="$(mktemp -d)"
trap 'kill "${LPID:-0}" 2>/dev/null; rm -rf "$TMP"' EXIT
mkdir -p "$TMP/proj/.hallux/.telemetry" "$TMP/proj/sub"
SOCK="$TMP/proj/.hallux/.telemetry/socket-1"
OUT="$TMP/events.jsonl"

python3 - "$SOCK" "$OUT" <<'PY' &
import socket, sys
s = socket.socket(socket.AF_UNIX); s.bind(sys.argv[1]); s.listen(5)
while True:
    c, _ = s.accept()
    d = b""
    while (b := c.recv(4096)): d += b
    open(sys.argv[2], "ab").write(d)
    c.close()
PY
LPID=$!; sleep 0.3
for _ in $(seq 50); do [[ -S "$SOCK" ]] && break; sleep 0.1; done

fail() { echo "FAIL: $1"; exit 1; }

# No telemetry dir: silent no-op
(cd "$TMP" && source "$ROOT/bin/logging.sh" && emit_telemetry process_start '{}') || fail "no-op"
[[ ! -s "$OUT" ]] || fail "emitted without telemetry dir"

# Discovery walking upward, and process_start/process_end
(cd "$TMP/proj/sub" && env -u HX_ROOT -u HX_TELEMETRY_SOCKET bash -c \
  'source "$1/bin/logging.sh"; telemetry_start a "b c"; telemetry_end_on_exit' _ "$ROOT")
sleep 0.5
jq -e -s 'length==2 and .[0].event=="process_start" and .[0].args==["a","b c"] and .[1].event=="process_end" and .[1].exit_code==0 and (.[0].session_id|length>0)' "$OUT" >/dev/null || { cat "$OUT"; fail "events"; }
echo "PASS"
