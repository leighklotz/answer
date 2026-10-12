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
