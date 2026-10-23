## Summary

This PR introduces **`decide`**, a new structured decision command for the Hallux toolchain, along with **`hx schema build`**, an interactive DSL for authoring the decision schemas it consumes.

Where `ask` and `help` are conversational and generative (NL in, NL out), `decide` is extractive and deterministic: **schema + context in, typed JSON out**. It's the command you reach for when a shell script needs to *branch* on an answer rather than *read* one.

Under the hood, `decide` is a single stateless `POST /v1/systemone` to the Jev Structured Decision API (model: `decision-model-preview`). Every question is evaluated in parallel and in isolation against the same state — no text generation, nothing to parse, predictable latency and cost.

## What's included

| File | Change |
|------|--------|
| `bin/decide.sh` | Reference implementation of the `/v1/systemone` wire format (request shape + typed answer shapes) |
| `bin/commands/schema.sh` | New `hx schema build` interactive DSL for compiling decision schemas to JSON |
| `doc/commands/decide.md` | Full reference for `decide`: synopsis, schema format, output modes, example workflows, exit codes |
| `doc/hx-schema-usage.md` | Usage patterns for the schema-builder DSL (interactive + scripted) |
| `HALLUX.md` | Register `decide` as capability **C. Data Classification and Scoring**; rename capability B from `nuextract` → `extract`; renumber Safety Gateways to D |

## The three answer types

| Type | Response shape | Meaning |
|------|----------------|---------|
| `noul` | `{ type, noul }` | Probability of "yes", 0–1. No criteria needed. |
| `choice` | `{ type, choice, probabilities, confidence }` | Model picks one key from your `criteria` map. |
| `score` | `{ type, score, legend, probabilities, confidence }` | Continuous score against an ordered criteria legend. |

## Usage

**Build a schema from positional DSL arguments:**

```bash
hx schema build "Support Ticket Triage" \
  select department choice "Route to team" \
  option billing "Payments" \
  option technical "Bugs" \
  option sales "Inquiry" \
  select is_urgent noul "Immediate action required?" \
  > triage.json
```

**Then use it as a pipeline gate:**

```bash
bx tail -n 20 /var/log/syslog \
  | ask "Summarize the errors you see" --answer \
  | decide schemas/triage.json --json \
  | jq '.department.choice'
```

`decide` auto-detects stdin — Hallux pipeline history (magic header → last assistant message) or raw text — and supports three output modes: terminal summary (default TTY), `--json` (data mode), and `--tee` (summary on stderr, full response on stdout for continued piping).
