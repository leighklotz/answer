# help

**help** is a specialized wrapper for the `ask` command, pre-configured with a system prompt optimized for high-precision technical assistance. It is designed for rapid, concise queries regarding Linux administration, Bash scripting, Python programming, and general software engineering.

## Synopsis

```bash
help [OPTIONS] [PROMPT...]
```

The first non-flag argument begins the prompt.

## Description

`help` is a convenience command that automatically injects a specialized `SYSTEM_MESSAGE` into the LLM context. While `ask` is a general-purpose state builder, `help` is tuned for efficiency: it is configured to provide direct answers and executable code while **avoiding unnecessary exposition** (optimized for a one-shot, question-and-response workflow).

**Note:** While `help` uses a default technical persona, you can override this behavior by setting the `SYSTEM_MESSAGE` environment variable before running the command.

When used in a pipeline, `help` behaves exactly like `ask`, managing conversational history and allowing for complex, stateful technical workflows.

## Options

Since `help` is a wrapper for `ask`, it supports all `ask` options:

| Flag | Long form | Description |
|------|-----------|-------------|
| `-i` | `--input` | **Attachment Mode:** Treats `stdin` as raw text to be prepended to the `PROMPT` (as an "attachment") rather than as a JSON conversation history. In a terminal, this enables multi-line input (terminated with `Ctrl-D`). |
| `-t` | `--tee` | **Observation Mode:** Prints the human-readable response to **stderr** while passing the updated, resolved JSON conversation history to **stdout**. |
| `--help` | | Print usage information and exit. |

## Input Modes

| Condition | Behavior |
|-----------|----------|
| **Interactive (Terminal)** | Reads the command-line arguments as the user's prompt. |
| **Piped (JSON History)** | If `stdin` starts with the `PIPELINE_MAGIC_HEADER`, it treats the input as a JSON conversation history. |
| **Piped (Raw Text)** | If `stdin` is a pipe but contains raw text, it treats the incoming text as context to be prepended to the prompt. |

## Examples

**1. Quick Technical Query**
Get immediate assistance with a Linux command or programming concept.
```bash
$ help "How do I recursively find all .log files larger than 100MB?"
```

**2. Analyzing Command History**
Pass your recent shell history to `help` to understand or refactor what you have been doing.
```bash
$ history 20 | help "Explain the commands I just ran and suggest improvements"
```

**3. Debugging Command Output**
Pipe the output of a failing command directly into `help` to diagnose the issue.
```bash
$ dmesg | tail -n 20 | help "Are there any critical hardware errors here?"
```

**4. Code Generation and Refactoring**
Use it within a pipeline to transform code or scripts.
```bash
$ cat script.sh | help "Refactor this to use associative arrays" | unfence | bash
```

**5. Chained Technical Investigation**
Use mid-pipeline observation to see the logic while continuing the conversation.
```bash
$ ls -l | help -t "Explain these permissions" | help "How would I change them for the owner?"
```
