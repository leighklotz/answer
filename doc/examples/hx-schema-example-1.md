
```markdown
klotz@tensor:~/wip/answer👣$ cat tests/test-hx-schema.sh 
#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# in tests/
source "${SCRIPT_DIR}/../bin/commands/hx-bootstrap.sh"

hx core

# hx schema build "Support Ticket Triage" \
#  select department choice --instructions "Route to team" \
#  option billing:Payments,technical:Bugs,sales:Inquiry \
#  select is_urgent noul --instructions "Immediate action required?" \
#  finish triage.json
#


hx schema build "Support Ticket Triage" <<'EOF'
select department choice --instructions "Route to team"
option billing:Payments,technical:Bugs,sales:Inquiry
select is_urgent noul --instructions "Immediate action required?"
finish triage.json
EOF
klotz@tensor:~/wip/answer👣$ tests/test-hx-schema.sh

Building schema for: Support Ticket Triage
Commands: select <name> [type] | option <vals> | finish

💬   ✓ Field 'department' (type: choice) initialized.
💬   ✓ Options added to 'department'.
💬   ✓ Field 'is_urgent' (type: noul) initialized.
💬 Schema saved to triage.json

klotz@tensor:~/wip/answer👣$ cat triage.json 
{
  "questions": {
    "department": {
      "type": "choice",
      "instructions": "",
      "criteria": {
        "billing": "Payments",
        "technical": "Bugs",
        "sales": "Inquiry"
      },
      "probabilities": {}
    },
    "is_urgent": {
      "type": "noul",
      "instructions": ""
    }
  }
}
klotz@tensor:~/wip/answer👣$ 
```
