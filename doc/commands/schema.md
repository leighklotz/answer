# hx schema

Builds a decision schema consumed by `decide`. The DSL is a tiny stream of
commands; everything is positional and required — nothing is inferred, and
every mistake fails loudly instead of being silently absorbed.

### Usage Patterns

#### Create a schema file

The schema is written to stdout, so it can be redirected straight into a file.

```bash
$ hx schema build "Support Ticket Triage" \
  select urgency score "How high is the priority?" option 'low|medium|high' \
  select department choice "Route to team" \
  option billing "Payment or subscription issues" \
  option technical "Bugs or integration problems" \
  option sales "Pricing or account questions" \
  select is_urgent noul "Immediate action required?" \
  > triage.json
```

#### Single-command pipeline usage

```bash
#!/bin/bash
hx schema build "Security Gate" \
  select is_authorized noul "Does user have admin rights?" \
  select risk_level score "Potential threat level" option 'low|medium|high' \
  > security_rules.json

# Now use it in the Hallux pipeline!
bx tail -n 50 /var/log/auth.log | ask "Analyze these logs for unauthorized access?" | decide security_rules.json
```

### DSL Reference

#### `select <name> <type> <instructions...>`

Declares a field. All three parts are required:

* `<name>` — unique field name; declaring it twice is an error
* `<type>` — exactly one of:

  | type | meaning |
  |---|---|
  | `choice` | pick one of several keyed criteria |
  | `score` | judge against an ordered legend of levels |
  | `noul` | probability 0..1 decided at runtime |

* `<instructions...>` — every remaining word on the command, joined with
  spaces; REQUIRED even when empty — pass an explicit `""`:

  ```bash
  select urgency score "How high is the priority?"
  select is_urgent noul "Immediate action required?"
  select meta noul ""
  ```

#### `option <args...>` (alias: `options`)

Must follow its `select`; semantics follow the field's declared type:

* **choice** — `option <key> [<description...>]` adds one entry; lines
  accumulate; duplicate keys are an error. The description is all remaining
  words joined, and may be empty.

  ```bash
  option billing "Payment or subscription issues"
  ```

* **score** — `option <level...>` appends level labels in order; a single
  token is split on `|`:

  ```bash
  option "low|medium|high"
  option "Calm, just stating facts" "Frustrated but civil" "Very angry, strong language"
  ```

* **noul** — rejected; the probability is decided at runtime.

At the end, `schema` validates the accumulated schema and writes it to stdout. If
any earlier command errored, it refuses to write and exits non-zero.

### Caveats
Argument-form caveat: a token that is exactly select/option/options
starts a new command — instruction or description text must not begin
with one of those words.

### Debugging

Set `HALLUX_SCHEMA_DEBUG=1` to echo the parsed commands (positional args
and flags) while building. Note: the flag-echo field only populates on
input paths that parse flags; the argument form (`hx schema build …`)
has no flags, so expect the flags field to be empty there.
