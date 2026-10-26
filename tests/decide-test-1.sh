#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Enable Hallux Core
source "${SCRIPT_DIR}/../bin/commands/hx-bootstrap.sh"
hx core

# - `triage.json` holds a `questions` map — each key is a question, each value declares `type`, `instructions`, and (for `choice`/`score`) `criteria`.
# - `decide` auto-detects raw text on stdin; no magic header needed here.
# - `--json` emits only the answers object, so selectors are root-level.

# --- 1. Create the schema ---
hx schema build "Support Ticket Triage" \
  select department choice "Which team should handle this?" \
  option billing "Payments, refunds, duplicate charges" \
  option technical "Bugs, site errors, login problems" \
  option sales "New purchases, product inquiries" \
  select is_urgent noul "Is immediate action required?" \
  > triage.json

# --- 2. Pipe raw text through decide (data mode) ---
# Note: options must precede the positional schema file.
echo "User reports: my invoice was charged twice for the Pro plan on 06/15 and I was told it's a billing glitch but it's been 3 weeks." \
  | decide --json triage.json

# --- 3. Branch on the result ---
answer=$(echo "My API integration started returning 502 errors after the deploy and the staging env is down." \
  | decide --json triage.json)

dept=$(echo "$answer" | jq -r '.department.choice')
urgent=$(echo "$answer" | jq -r '.is_urgent.noul')

echo "Department: $dept"
echo "Urgency:    $urgent"

if [[ "$dept" == "technical" && $(echo "$urgent > 0.7" | bc) -eq 1 ]]; then
  echo "→ Escalating to on-call engineer"
fi
