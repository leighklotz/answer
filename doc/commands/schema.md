### Usage Patterns

#### 1. Example 1

```bash
$ hx schema build "Support Ticket Triage" \
 select urgency score instructions "How high is the priority?" option 'low|medium|high' \
 select department choice instructions "Route to team" option 'Billing:Payments,Tech:Support,Sales:Inquiry' \
 select is_urgent noul instructions "Immediate action required?" \
 > triage.json
```

#### 2. Example 2

```bash
#!/bin/bash
# Using the DSL as a single command execution (via heredoc or manual expansion)

hx schema build "Security Gate" \
  select is_authorized noul --instructions "Does user have admin rights?" \
  select risk_level score --instructions "Potential threat level" option low|medium|high \
  > security_rules.json

# Now use it in the Hallux pipeline!
bx tail -n 50 /var/log/auth.log | ask "Analyze these logs for unauthorized access?" --answer | decide security_rules.json
```
