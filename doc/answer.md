# answer

**answer** is the "Text Extractor" and pipeline "Cut-Point" in the Answer framework. It bridges the gap between LLM conversation state (JSON) and standard shell execution (Plain Text). It is a **state-resolving** command: if the input history ends with a `user` message, `answer` will automatically trigger the inference engine to complete the turn before extracting the resulting assistant text.

The `answer` command is a shell function that provides an enhanced interactive interface (supporting `--tee` and `LAST_ANSWER` retrieval) by wrapping the core `answer.sh` execution script.

## Synopsis

```bash
<conversation-json> | answer [OPTIONS]
```

## Description

In a pipeline, `ask` and `tools` pass heavy JSON arrays to maintain conversation state. The `answer` command acts as a gatekeeper that allows you to transition from "conversation mode" (passing JSON) to "tooling/shell mode" (passing plain text).

### The Resolution Step
Unlike a simple parser, `answer` is an active participant in the pipeline. If the incoming JSON history represents an incomplete conversation (i.e., the last message is from the `user`), `answer` executes an inference to generate the assistant's response. It then strips the JSON metadata and delivers the final response as raw text.

## Options

| Flag | Long form | Description |
|------|-----------|-------------|
| `-t` | `--tee` | **Observation Mode:** (Provided by shell function) Mid-pipeline mode. Prints the plain text content of the last message to **stderr** (for your eyes) while passing the full JSON conversation array through to **stdout** (for the next command in the pipe). |

## Input Modes

| Condition | Behavior |
|-----------|----------|
| **Piped Input** | Reads the mime-header and JSON conversation array from `stdin`. If the array ends with a `user` message, `answer` infers the answer before extracting the text. |
| **Piped Input (Raw Text)** | Reads raw text from `stdin`, treats it as a single-turn history, resolves it, and outputs the assistant's response. |
| **Interactive (Terminal)** | (Provided by shell function) If called directly in a terminal and the global `LAST_ANSWER` variable is set, it retrieves and prints the content of that variable without requiring `stdin`. |

## Output Modes

The behavior of `answer` changes depending on how it is used in a pipeline:

| Mode | Context | stdout | stderr |
|------|---------|--------|--------|
| **Observation** (`--tee`) | Used mid-pipeline (e.g., `... | answer --tee | ask ...`) | The full JSON conversation array | The plain text content of the last message |
| **Extraction** (no flags, piped) | Used as a terminal endpoint for tools (e.g., `... | answer | python`) | The plain text content of the last message | cache icons / newline |
| **Terminal** (no flags, direct call) | Used at the end of a command chain in a terminal | The plain text content of the last message | cache icons / newline |

## Examples

**1. Direct Extraction (Terminal Mode)**
Get just the text response of the last turn in your terminal.
```bash
ask "What is the capital of France?" | answer
# Output: Paris
```

**2. The "Cut-Point" (Extraction Mode)**
Convert LLM output to a format that standard shell tools can consume.
```bash
ask "Write a python script to print 'hello'" | answer | unfence | python
```

**3. Observation Mode (Mid-Pipeline)**
See what the LLM is thinking/doing in the terminal, but keep the JSON state flowing so you can ask follow-up questions.
```bash
ask "Write a bash loop" | answer --tee | ask "Now add error handling" | answer
```
*In this example, the bash loop code appears on your screen (via `stderr`), but the `ask` command receives the JSON history via `stdout` to maintain context.*

