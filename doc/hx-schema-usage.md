### Usage Patterns (The DSL in Action)

#### 1. Interactive Building (Human-Centric)
This is ideal when you are sitting at the terminal and want to "sculpt" your decision logic through a series of prompts.

```bash
$ hx schema build "Support Ticket Triage"
Building schema for: Support Ticket Triage (Press Enter to start)

> select urgency score --instructions "How high is the priority?"
  ✓ Field 'urgency' initialized.
> option low|medium|high
  ✓ Options added to 'urgency'.
> select department choice --instructions "Route to team"
  ✓ Field 'department' initialized.
> option Billing:Payments,Tech:Support,Sales:Inquiry
  ✓ Options added to 'department'.
> select is_urgent noul --instructions "Immediate action required?"
  ✓ Field 'is_urgent' initialized.
> finish triage.json

Schema saved to triage.json
```
43;20M
#### 2. Scripted/Pipeline Building (Automation-Centric)
Because the commands are designed as a sequence, you can write your schema definitions in simple `.schema` files and "compile" them into JSON for use with `decide`. This is how complex automation pipelines define their intelligence gates.

**Example: Creating an automated gate script (`setup_gate.sh`)**
```bash
#!/bin/bash
# Using the DSL as a single command execution (via heredoc or manual expansion)

hx schema build "Security Gate" \
  select is_authorized noul --instructions "Does user have admin rights?" \
  select risk_level score --instructions "Potential threat level" option low|medium|high \
  finish security_rules.json

# Now use it in the Hallux pipeline!
bx tail -n 50 /var/log/auth.log | ask "Analyze these logs for unauthorized access?" --answer | decide security_rules.json
```
