# decide

**`decide`** is a structured decision gate in the Hallux toolchain. It transforms unstructured text or conversation history into deterministic, typed answers by applying a user-supplied JSON schema against a state via the **Jev Structured Decision API** (`POST /v1/systemone`).

Where `ask` and `help` are conversational and generative (natural-language in, natural-language out), `decide` is extractive and deterministic (schema + context in, typed JSON out). It is the command you reach for when a shell script needs to *branch* on an answer rather than *read* one.

## Synopsis

```
<conversation-json | raw-text> | decide [OPTIONS] <schema_file>
```

The default decision model is `laya-q8_0`, overridable per environment via `$HX_DECISION_MODEL` or per invocation via `--model`.

## Arguments

| Argument | Description |
|----------|-------------|
| `<schema_file>` | Path to a JSON file containing a single `questions` object; each key is your question name and each value declares its `type`, `instructions`, and (where applicable) `criteria`. This is the format `hx schema build` emits — see `doc/commands/schema.md`. |

## Options

| Flag | Long form | Description |
|------|-----------|-------------|
| `-s` | `--schema FILE` | Path to the JSON schema (alternative to the positional argument). |
| `--model STRING` | | Override the decision model (default: `laya-q8_0`, or `$HX_DECISION_MODEL`). |
| `-j` | `--json` | **Data mode.** Emit only the `answers` object on `stdout` — no prose, no headers. Designed for direct piping into `jq` or downstream automation. |
| `-t` | `--tee` | **Observation mode.** Print a human-readable summary to `stderr` while passing the full JSON response (prefixed with the pipeline magic header) through `stdout` for further piping. |

With no flags, `decide` pretty-prints the full response JSON on `stdout` — TTY or not. All chatter (log lines, the `✨` inference icon, the `--tee` summary) goes to `stderr`.

## Input Modes

`decide` auto-detects the shape of its stdin:

| Condition | Detection | State extraction |
|-----------|-----------|------------------|
| **Pipeline JSON history** | First line matches the Hallux magic header (`Content-Type: application/x-llm-history+json`) | Last `assistant` message `.content` is used as the state. Enables `ask → decide` chaining. |
| **Bare conversation array** | Stdin parses as a JSON array | Same as pipeline history: last `assistant` message `.content` is the state, without needing the magic header. |
| **Raw text** | Anything else | The entire stdin stream is the state. Use for piping logs, command output, or `ask --answer`. |

If stdin is empty or whitespace-only, `decide` exits **1** with a diagnostic on `stderr`.

## Decision Schema

The schema file contains a single `questions` object where each key is a question name and each value is a question definition. `hx schema build` (see `doc/commands/schema.md`) is the primary way to author this file:

```json
{
  "questions": {
    "<question_name>": {
      "type": "choice | score | noul",
      "instructions": "Natural-language prompt for the model",
      "criteria": { ... }   // required for choice & score
    }
  }
}
```

### Answer types

| `type` | Response shape | Meaning |
|--------|---------------|---------|
| `noul` | `{ "type": "noul", "noul": 0.87 }` | Probability of "yes" (0 – 1). No criteria needed. |
| `choice` | `{ "type": "choice", "choice": "billing", "probabilities": {…}, "confidence": 0.94 }` | Model picks one key from your `criteria` map. |
| `score` | `{ "type": "score", "score": 0.98, "legend": {…}, "probabilities": {…}, "confidence": 0.91 }` | Model assigns a continuous score; `legend` maps level index → description. `criteria` is an *ordered* array. |

Every response also carries a top-level `usage` object with `input_tokens` and `output_tokens`.

### Schema example (`schemas/triage.json`)

Authored via `hx schema build`:

```bash
hx schema build "Support Ticket Triage" \
  select department choice "Which team should handle this ticket?" \
  option billing "Payment or subscription issues" \
  option technical "Bugs or integration problems" \
  option sales "Pricing or account questions" \
  select urgency score "How critical or time-sensitive is this?" \
  option 'Low – informational, no action needed|Medium – should be addressed within a day|High – blocking, needs same-day response|Critical – revenue-impacting, escalate now' \
  select is_urgent noul "The message conveys urgency or time-sensitivity." \
  > schemas/triage.json
```

which produces:

```json
{
  "questions": {
    "department": {
      "type": "choice",
      "instructions": "Which team should handle this ticket?",
      "criteria": {
        "billing":   "Payment or subscription issues",
        "technical": "Bugs or integration problems",
        "sales":     "Pricing or account questions"
      },
      "probabilities": {}
    },
    "urgency": {
      "type": "score",
      "instructions": "How critical or time-sensitive is this?",
      "criteria": [
        {"level": "Low – informational, no action needed"},
        {"level": "Medium – should be addressed within a day"},
        {"level": "High – blocking, needs same-day response"},
        {"level": "Critical – revenue-impacting, escalate now"}
      ],
      "probabilities": {}
    },
    "is_urgent": {
      "type": "noul",
      "instructions": "The message conveys urgency or time-sensitivity."
    }
  }
}
```

## Output Modes

| Mode | Trigger | `stdout` | `stderr` |
|------|---------|----------|----------|
| **Full response** (default) | no flags | Full response JSON, pretty-printed | `decide:` logs, model/endpoint line, ✨ inference icon |
| **Data** | `--json` / `-j` | Raw `answers` JSON object | ✨ inference icon |
| **Observation** | `--tee` / `-t` | Magic header + full response JSON (pipeline-ready) | Human-readable one-line-per-question summary block |

## Example Workflows

### 1. Intelligent Router — ask → decide

Use a heavy-reasoning `ask` call to summarise messy system state, then classify the summary into structured data your script can act on:

```bash
bx tail -n 20 /var/log/syslog \
  | ask "Summarize the errors you see" --answer \
  | decide schemas/triage.json --json
```

Output (`--json`):

```json
{
  "department": { "type": "choice", "choice": "technical", "probabilities": {"technical":0.91,"billing":0.05,"sales":0.04}, "confidence":0.93 },
  "urgency":    { "type": "score",  "score":0.82, "legend":{…}, "probabilities":{…}, "confidence":0.88 },
  "is_urgent":  { "type": "noul",   "noul": 0.91 }
}
```

### 2. Pipeline Bridge — observe *and* continue

Preview the decision on your terminal while passing the full structured response down a longer pipeline:

```bash
ask "Should this user be allowed to run 'rm -rf'?" \
  | decide schemas/risk.json --tee \
  | jq '.answers.risk.level' \
  | awk '{ if ($1 < 0.5) system("./rollback.sh") }'
```

`stderr` shows one `name: value` line per question:

```
💬︎ decision
risk: score=0.32 (conf=0.87)
is_urgent: noul=0.74
```

`stdout` carries the magic-header-prefixed JSON so any downstream Hallux command can resume the conversation.

### 3. Automated Incident Response

Trigger a PagerDuty-style alert only when `decide` classifies the incident as auth-related *and* urgent:

```bash
cat /var/log/auth.log \
  | ask --answer \
  | decide schemas/triage.json --json \
  | jq -r '
      if (.department.choice == "auth" and .is_urgent.noul > 0.8)
      then "PAGE" else "OK" end' \
  | { read -r verdict; [[ "$verdict" == "PAGE" ]] && curl -X POST "$PAGERDUTY_URL"; }
```

### 4. Git-Commit Quality Gate (with `gx`)

Score a diff before merge:

```bash
gx diff HEAD~1..HEAD \
  | decide schemas/commit-quality.json --json \
  | jq '.answers.breaks_api.noul' \
  | awk '{ exit ($1 > 0.7) }'   # non-zero exit → CI fails the PR
```

## Integration with the Hallux Ecosystem

| Tool | Role with `decide` |
|------|--------------------|
| `ask` | Upstream: produces the free-text state or JSON history that `decide` classifies. Chain with `\|`. |
| `hx schema build` | Upstream: authors the `questions`-object schema file (see `doc/commands/schema.md`). |
| `lx` | Upstream: stream file contents as context before `ask` or directly before `decide`. |
| `bx` | Upstream: capture command output as structured context for the decision. |
| `unfence` | Downstream: if a later `ask` generates a script based on the decision, `unfence` extracts it for execution. |
| `hx provenance add` | Post-hoc: bookmark a successful `decide` invocation into Git metadata for audit. |

`decide` sources `env.sh`, `logging.sh`, and `functions.sh` from `bin/` (loaded by `hx-bootstrap.sh`), reusing the shared `log_and_error`, `_mktemp_reg`, and pipeline-header constants. It is **not** an LLM call in the conversational sense — it is a single, stateless POST to the decision endpoint with a fixed schema, so latency and cost are predictable and low.

## Exit Codes

| Code | Meaning |
|------|---------|
| `0` | Decision completed; answers emitted. |
| `1` | Missing / unreadable schema file, empty stdin, API error, or `curl` failure. Diagnostic on `stderr`. |
| `2` | Interrupted. |

## Notes & Gotchas

| Situation | What to do |
|-----------|------------|
| You need plain text (not JSON) in a script | Use `--tee` and read `stderr`, or `--json \| jq -r …`. The no-flag default emits the full response JSON on `stdout`. |
| You are chaining `ask` → `decide` and `ask` emitted JSON history | No action needed — `decide` auto-detects the magic header and extracts the last assistant message. |
| You are piping a bare JSON conversation array (no magic header) | Also accepted — the last `assistant` message becomes the state. |
| You are piping raw text (e.g. `cat logfile \| decide …`) | Also fine — the entire stream becomes the state. Just make sure it is non-empty. |
| You need a different model | Pass `--model your-model-id`, or export `HX_DECISION_MODEL` in the environment. Default is `laya-q8_0`. |
| Multiple schema files | `decide` accepts exactly one schema per invocation. To combine, merge the JSON objects in a temp file or a second `jq -s 'add'` step upstream. |

## Model Reference

Default model: `laya-q8_0` (`$HX_DECISION_MODEL` / `--model` override).
