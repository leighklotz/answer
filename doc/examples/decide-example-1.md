```bash
#!/usr/bin/env bash
set -euo pipefail
source "${SCRIPT_DIR}/../bin/commands/hx-bootstrap.sh"

hx core

# --- 1. Create the schema ---
hx schema build "Support Ticket Triage" \
  select department choice "Route to team" \
  option billing "Payments" \
  option technical "Bugs" \
  option sales "Inquiry" \
  select is_urgent noul "Immediate action required?" \
  > triage.json

# --- 2. Pipe raw text through decide (data mode) ---
echo "User reports: my invoice was charged twice for the Pro plan on 06/15 and I was told it's a billing glitch but it's been 3 weeks." \
  | decide triage.json --json

# --- 3. Branch on the result ---
answer=$(echo "My API integration started returning 502 errors after the deploy and the staging env is down." \
  | decide triage.json --json)

dept=$(echo "$answer" | jq -r '.department.choice')
urgent=$(echo "$answer" | jq -r '.is_urgent.noul')

echo "Department: $dept"
echo "Urgency:    $urgent"

if [[ "$dept" == "technical" && $(echo "$urgent > 0.7" | bc) -eq 1 ]]; then
  echo "→ Escalating to on-call engineer"
fi
```

**Expected `--json` output (step 2):**

```json
{
  "department": {
    "type": "choice",
    "choice": "billing",
    "probabilities": {"billing": 0.92, "technical": 0.04, "sales": 0.04},
    "confidence": 0.94
  },
  "is_urgent": {
    "type": "noul",
    "noul": 0.71
  }
}
```

**Key points:**

- `triage.json` holds a `questions` map — each key is a question, each value declares `type`, `instructions`, and (for `choice`/`score`) `criteria`.
- `decide` auto-detects raw text on stdin; no magic header needed here.
- `--json` emits only the `answers` object so you can pipe straight into `jq` and branch in your script.
