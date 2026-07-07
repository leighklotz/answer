# doc/answer.md
```markdown
# answer

**answer** is the text extractor and pipeline cut-point in Answer. It bridges the gap between LLM conversation state (JSON) and standard shell execution (Plain Text). It is a **state-resolving** command: if the incoming JSON history ends with a `user` message, `answer` will automatically trigger the inference engine to complete the turn before extracting the assistant text. You should use `answer` when you need the last response of an inference pipeline to be extracted from the conversation and output to something other than a terminal, such as a pipe or a file.

## Synopsis

```bash
<conversation-json> | answer [OPTIONS]
```

## Description

In a pipeline, commands like `ask` or `tools` pass heavy JSON arrays to maintain conversation state. The `answer` command acts as the gatekeeper that allows you to transition from "conversation mode" (passing structured JSON) to "tooling/shell mode" (passing pristine plain text).

### The Resolution Step
Unlike a simple parser, `answer` is an active participant in the pipeline. If the incoming JSON history represents an incomplete conversation—meaning the last message is from the `user`—`answer` executes a call to the internal `_infer()` engine to generate the assistant's response. Once resolved, it strips all metadata and delivers only the final text content.

## Options

| Flag | Long form | Description |
|------|-----------|-------------|
| `-t` | `--tee`   | **Observation Mode:** (Provided by shell function) Mid-pipeline mode. Prints the plain text content of the last message to **stderr** for human readability while passing the full, updated JSON conversation array through to **stdout** so context is preserved for the next command in the pipe. |

## Input Modes

| Condition | Behavior |
|-----------|----------|
| **Piped (JSON History)** | Reads a `PIPELINE_MAGIC_HEADER` and the JSON conversation array from `stdin`. If the last message is from the user, it triggers inference to resolve the turn before extracting text. |
| **Piped (Raw Text/Context)** | Treats incoming raw text as part of an existing state or context; resolves via `_infer` if necessary, then extracts the resulting assistant response. |

## Output Modes

The behavior of `answer` depends on whether you are using it as a mid-pipeline observation point, an execution endpoint (piped), or for interactive display:

| Mode | Context | stdout | stderr |
|------|---------|--------|--------|
| **Observation** (`--tee`) | Used mid-pipeline to see progress without breaking the chain (e.g., `... \| answer --tee \| ask ...`) | The full, updated JSON conversation array | Plain text content of the last message + inference status emojis/icons |
| **Extraction** (no flags, piped) | Used as a terminal endpoint for tools (e.g., `... \| answer \| python`) | Raw plain text content of the assistant's response | Inference status emojis/icons from `_infer` |
| **Terminal** (via shell function) | End-of-line interaction in an active terminal session | The human-readable message text | Message formatting icons + newline for visual separation |

## Examples

**1. Direct Extraction (Terminal Mode)**
Retrieve the plain text of a previous conversation turn directly in your prompt.
```bash
$ ask "What is 2+2?" | answer
4
```

**2. The "Cut-Point" (Extraction Mode for Tooling)**
Convert LLM output into clean text that standard shell tools like `python` or `bash` can process without JSON interference.
```bash
ask "Write a python script to print 'Hello World'" | answer | unfence | python
```

**3. Observation Mode (Mid-Pipeline Logic)**
See the response in your terminal so you can read it, while passing the updated state down the pipe so you can continue the conversation with another `ask`.
```bash
ask "Plan a complex bash script" | answer --tee | ask "Now add logging to that plan"
```
*In this pattern: The code appears on your screen (via stderr), but the JSON history continues through stdout for the next command.*


