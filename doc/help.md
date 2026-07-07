# help

**help** is a specialized wrapper for the `ask` command, pre-configured with a system prompt optimized for high-precision technical assistance. It is designed for rapid, concise queries regarding Linux administration, Bash scripting, Python programming, and general software engineering.

## Synopsis

```bash
help [OPTIONS] [PROMPT...]
```

The first non-flag argument begins the prompt.

## Description

`help` is a convenience command that automatically injects a specialized `SYSTEM_MESSAGE` into the LLM context to ensure highly technical, concise, and executable responses. While `ask` is a general-purpose state builder for any conversation type, `help` is tuned for efficiency: it is configured to provide direct answers and actionable code while **avoiding unnecessary exposition**.

**Note:** By default, `help` uses the "Technical Assistant" persona (optimized for coding/Linux). You can override this global behavior by setting the `SYSTEM_MESSAGE` environment variable before running the command. Because of how `help` is implemented, it always operates in `--use-system-message` mode to ensure context integrity.

When used in a pipeline, `help` behaves exactly like `ask`, managing conversational history and allowing for complex, stateful technical workflows through JSON objects.

## Options

Since `help` acts as an optimized interface for `ask`, it supports all of its operational flags:

| Flag | Long form | Description |
|------|-----------|-------------|
| `-i` | `--input` | **Attachment Mode:** Treats `stdin` (from a pipe or TTY) as raw text to be appended with an `ATTACHMENT:` label. In a terminal, this enables multi-line input via Ctrl+D. |
| `-t` | `--tee` | **Observation Mode:** Prints the human-readable response to **stderr** while passing the updated JSON conversation history through **stdout**. This is essential for mid-pipeline inspection. |

## Input Modes

Since `help` inherits all logic from `ask`, it supports multiple input streams:

| Condition | Behavior |
|-----------|----------|
| **Interactive (Terminal)** | Reads command-line arguments as the user's prompt and outputs to terminal via a human-readable format. |
| **Piped (JSON History)** | If `stdin` starts with `PIPELINE_MAGIC_HEADER`, it treats the input as an existing JSON conversation history to be extended. |
| **Piped (Raw Text) + Prompt** | Treats incoming text from `stdin` as context, appended to your command-line prompt. |

## Examples

**1. Quick Technical Query**
Get immediate assistance with a Linux command or programming concept without setting up complex environment variables.
```bash
$ help "How do I recursively find all .log files larger than 100MB?"
```

**2. Analyzing Command History**
Pipe your recent shell history into `help` to have an LLM explain and optimize your workflow.
```bash
$ history 20 | help "Explain the commands I just ran and suggest improvements"
```

**3. Debugging Pipeline Output**
Directly pipe error logs or command outputs for instant diagnosis.
```bash
$ dmesg | tail -n 20 | help "Are there any critical hardware errors here?"
```

**4. Code Generation & Refactoring in a Pipe**
Use `help` to transform code, passing the output through an extraction tool like `unfence`.
```bash
$ cat script.sh | help "Refactor this to use associative arrays" | unfence | bash
```

**5. Mid-Pipeline Observation**
Use `-t` (tee) to monitor the LLM's thought process or response in your terminal without breaking a JSON pipeline intended for another tool.
```bash
$ ls -l | help "Explain these permissions" --tee | ask "Now show me how to change them"
```
