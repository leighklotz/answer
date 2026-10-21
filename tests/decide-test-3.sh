#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Enable Hallux Core
source "${SCRIPT_DIR}/../bin/commands/hx-bootstrap.sh"
hx core

# - `triage.json` is a flat map — each key is a question, each value declares `type`, `instructions`, and (for `choice`/`score`) `criteria`.
# - `decide` auto-detects raw text on stdin; no magic header needed here.
# - `--json` emits only the `answers` object so you can pipe straight into `jq` and branch in your script.

# --- 1. Create the schema ---
hx schema build "Support Ticket Triage" \
  select requires_human_routing noul "Does this issue need a human agent?" \
  select department choice "Which team should handle this?" \
  option billing "Payments, refunds, duplicate charges" \
  option technical "Bugs, site errors, login problems" \
  option sales "New purchases, product inquiries" \
  > triage.json

cat > ticket.txt <<EOF
Customer message: I was charged twice for my order last week and nobody has replied.
EOF

# --- 2. Pipe raw text through decide (data mode) ---
echo "ticket"
cat ticket.txt | ask "Triage this support ticket" | decide triage.json

