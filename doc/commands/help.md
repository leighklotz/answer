# help

**help** is a specialized wrapper for the `ask` command, pre-configured with a system prompt optimized for high-precision technical assistance. It is designed for rapid, concise queries regarding Linux administration, Bash scripting, Python programming, and general software engineering.

## Synopsis

```bash
help [OPTIONS] [PROMPT...]
```

The first non-flag argument begins the prompt.

## Description

`help` is a convenience command that automatically injects a specialized `SYSTEM_MESSAGE` into the LLM context to ensure highly technical, concise, and executable responses. While `ask` is a general-purpose state builder for any conversation type, `help` is tuned for efficiency: it is configured to provide direct answers and actionable code while **avoiding unnecessary exposition** (minimizing conversational "fluff").

Because of how `help` is implemented in the shell environment, it always operates as if the `--use-system-message` flag were passed. This ensures that every query benefits from a "Technical Assistant" persona by default.

When used in a pipeline, `help` behaves exactly like `ask`, managing conversational history and allowing for complex, stateful technical workflows through JSON objects.

## Options

Since `help` is an optimized interface built upon the logic of `ask`, it supports all its operational flags:

| Flag | Long form | Description |
|------|-----------|-------------|
| `-i` | `--input` | **Attachment Mode:** Treats `stdin` (from a pipe or TTY) as raw text to be appended with an `ATTACHMENT:` label. In a terminal, this enables multi-line input via Ctrl+D. |
| `-t` | `--tee`   | **Observation Mode:** Prints the human-readable response to **stderr** while passing the updated JSON conversation history through **stdout**. This is essential for mid-pipeline inspection without breaking chains. |

## Input Modes

As a wrapper of `ask`, it supports multiple input streams:

| Condition | Behavior |
|-----------|----------|
| **Interactive (Terminal)** | Reads command-line arguments as the user's prompt and outputs to terminal via a human-readable format. |
| **Piped (JSON History)** | If `stdin` starts with the `PIPELINE_MAGIC_HEADER`, it treats the input as an existing JSON conversation history to be extended. |
| **Piped (Raw Text) + Prompt** | Treats incoming text from `stdin` as context, appended to your command-line prompt. |

## Usage Patterns & Aliases

The power of `help` is most evident when used in combination with other utilities or through common productivity aliases:

### 1. The "Code Transformation" Pattern
You can quickly pipe the output of a technical question into an interpreter using these standard aliases:

* **To Python:** Transform a calculation or logic block into a runnable script.
  ```bash
  $ alias to_python='help output the calculation in a code fence as a python script to be used as stdin to `python`'
  $ help "calculate the 10th fibonacci number" | to_python
  65
  ```

* **To Bash:** Generate and execute shell commands immediately.
  ```bash
  $ alias to_bash='help output the calculation in a code fence as a bash script to be used as stdin to `bash`'
  $ help "list all files larger than 1G" | to_bash
  ```

* **To AWK:** Generate an awk filter for data processing.
  ```bash
  $ alias to_awk='help output the calculation in a code fence as an awk script to be used as stdin to \`awk -f -\`'
  $ echo "1 2" | help "add them together and print result" | to_awk
  3
  ```

### 2. Debugging & Diagnostics
Pipe system logs or command outputs directly into `help` for instant, noise-free diagnosis:
```bash
# Analyze dmesg for specific errors concisely
$ sudo dmesg | tail -n 50 | help "Are there any USB connection errors?"

# Explain complex file permissions
$ ls -la /etc/shadow | help "Who has read access to this and why is that important?"
```

### 3. Mid-Pipeline Observation
Use `-t` when you want to see the LLM's technical reasoning in your terminal, but need the resulting JSON state to be passed to a tool like `unfence`:
```bash
$ help "write a bash script to check disk space" --tee | unfence | bash
```
