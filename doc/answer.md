To ensure the documentation accurately reflects the provided source code, I have updated `doc/answer.md` to distinguish between the high-level `answer` shell function (which provides the user-facing features) and the `answer.sh` script (which acts as the low-level execution engine). I have also corrected the implementation notes in `doc/IMPL.md`, as the current version incorrectly claims the `answer.sh` script handles flags and interactive mode.

### Updated `doc/answer.md`

```markdown
# answer

**answer** is the "Text Extractor" and pipeline "Cut-Point" in the Answer framework. Its primary role is to strip away the JSON conversation history used by `ask` and `tools` to deliver the raw, human-readable text content of the final assistant message.

The `answer` command is a shell function that provides an enhanced interface (supporting `--tee` and interactive mode) by wrapping the core `answer.sh` execution script.

## Synopsis

```bash
<conversation-json> | answer [OPTIONS]
```

## Description

In a pipeline, `ask` and `tools` pass heavy JSON arrays to maintain conversation state. The `answer` command acts as a gatekeeper that allows you to transition from "conversation mode" (passing JSON) to "tooling/shell mode" (passing plain text).

## Options

| Flag | Long form | Description |
|------|-----------|-------------|
| `-t` | `--tee` | **Observation Mode:** (Provided by shell function) Mid-pipeline mode. Prints the plain text content of the last message to **stderr** (for your eyes) while passing the full JSON conversation array through to **stdout** (for the next command in the pipe). |

## Input Modes

| Condition | Behavior |
|-----------|----------|
| **Piped Input** | Reads the JSON conversation array from `stdin`. It is designed to recognize the `PIPELINE_MAGIC_HEADER` to ensure seamless transitions between `ask` stages. |
| **Interactive (Terminal)** | (Provided by shell function) If called directly in a terminal and the global `LAST_ANSWER` variable is set, it retrieves and prints the content of that variable. |

## Output Modes

The behavior of `answer` changes depending on how it is used in a pipeline:

| Mode | Context | stdout | stderr |
|------|---------|--------|--------|
| **Observation** (`--tee`) | Used mid-pipeline (e.g., `... | answer --tee | ask ...`) | The full JSON conversation array | The plain text content of the last message |
| **Extraction** (no flags, piped) | Used as a terminal endpoint for tools (e.g., `... | answer | python`) | The plain text content of the last message | _(nothing)_ |
| **Terminal** (no flags, direct call) | Used at the end of a command chain in a terminal | The plain text content of the last message | _(nothing)_ |

## Examples

**1. Direct Extraction (Terminal Mode)**
Get just the text response in your terminal.
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
```

---

### Updated `doc/IMPL.md` (Section: `answer.sh`)

```markdown
## `answer.sh`

**Language:** Bash  
**Dependencies:** `jq`

#### Input & Extraction
The script is a low-level utility designed to run within a pipeline. 
1. **Stdin Requirement:** It requires `stdin` to be present; it will exit if called in a purely interactive terminal (`[ -t 0 ]`).
2. **JSON Resolution:** It detects the `PIPELINE_MAGIC_HEADER` to identify existing conversation histories.
3. **Extraction Logic:** It uses `jq` to navigate the JSON array, targeting the `content` field of the very last object in the array. It includes safety checks to ensure the content is not null and is a valid string.

#### Output
The script outputs the extracted string to `stdout`. 

*Note: High-level features such as argument parsing (`--tee`), terminal-based `LAST_ANSWER` retrieval, and stderr/stdout splitting are handled by the `answer()` shell function defined in `functions.sh`, which wraps this script.*
```
