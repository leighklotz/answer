
```markdown
klotz@tensor:~/wip/answer👣$ cat tests/test-hx-schema.sh 
#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# in tests/
source "${SCRIPT_DIR}/../bin/commands/hx-bootstrap.sh"

hx core

hx schema build "Support Ticket Triage" \
  select department choice "Route to team" \
  option billing "Payments" \
  option technical "Bugs" \
  option sales "Inquiry" \
  select is_urgent noul "Immediate action required?" \
  > triage.json
klotz@tensor:~/wip/answer👣$ tests/test-hx-schema.sh
klotz@tensor:~/wip/answer👣$ cat triage.json 
{
  "questions": {
    "department": {
      "type": "choice",
      "instructions": "Route to team",
      "criteria": {
        "billing": "Payments",
        "technical": "Bugs",
        "sales": "Inquiry"
      },
      "probabilities": {}
    },
    "is_urgent": {
      "type": "noul",
      "instructions": "Immediate action required?"
    }
  }
}
klotz@tensor:~/wip/answer👣$ 
```
