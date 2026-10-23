# bx

**`bx`** is a command-execution bridge that executes shell commands and wraps their stdout within Markdown code fences. It is designed as an "injection" utility, transforming raw terminal output into structured, LLM-ready context that can be seamlessly consumed by the Answer toolchain.

## Synopsis

```bash
bx [-p|--plain] <command> [args...]
```

The command and its arguments are executed in your current shell environment.

| Flag | Long form | Description |
|------|-----------|-------------|
| `-p` | `--plain` | Suppress the Markdown code fences (```bash / ```). The command echo (`$ ...`) is still printed. Useful when the output does not need fence delimiters. |

## Description

When a command is executed via `bx`, it creates a self-contained Markdown block containing the command that was run and its output. This ensures that when this output is fed into an LLM, the model can distinguish between the instruction given to the system (the command) and the data returned by it.

### Execution Sequence
1.  **Fence Opening:** A Markdown code fence starting with ` ```bash ` is printed to `stdout` (omitted when `--plain` is set).
2.  **Command Echo:** The exact command and arguments passed to `bx` are printed on a new line, prefixed with a shell prompt (`$ `). Arguments are joined with `${*}`.
3.  **Execution:** The specified command is executed as `"$@"` in the current shell. Its **stdout is streamed directly into the open fence**. Its **stderr is captured**, each line prefixed with a `⚠️` icon, and also written into the fence on `stdout`.
4.  **Fence Closing:** The Markdown code fence is closed with ` ``` ` printed to `stdout` (omitted when `--plain` is set).
5.  **Status:** A `🐚` emoji is printed to `stderr` after the fence is closed.

## Pipeline Role: Context Injection

In a pipeline, `bx` acts as a **Context Provider**. While commands like `ask` or `help` manage conversational state and user prompts, `bx` provides the "ground-truth" system state from your terminal.

**The standard automation pattern is:**
```bash
# 1. Execute command to get context -> 2. Inject into LLM prompt -> 3. Extract/Execute result
bx <system_command> | ask "Analyze this output for errors." | unfence python | python
```

## Input Modes

| Condition | Behavior | Resulting Message Format |
|-----------|----------|------------------------|
| **Positional Arguments** | The provided arguments are treated as a single shell command to be executed and wrapped. | ` ```bash\n$ <cmd>\n<stdout>\n``` ` |
| **`-p` / `--plain`** | Same execution, but without the Markdown code fences. | `$ <cmd>\n<stdout>\n` |

## Output Modes

`bx` is primarily intended for use in pipelines, but its behavior changes based on your terminal environment:

| Mode | Context | stdout (Data stream) | stderr |
|------|---------|-------------------|--------|
| **Standard** | Used as a command in an interactive shell. | A formatted Markdown block containing the prompt (`$ `), the command's stdout, and any stderr lines prefixed with `⚠️`. | A `🐚` status emoji after completion. |
| **Piped/Automation** | Piped into another tool like `ask`/`help`. | The same structured Markdown block (stdout and `⚠️`-prefixed stderr); ideal for regex or parsing by specialized tools. | The `🐚` emoji goes to the terminal, not into the pipe. |

## Exit Code

`bx` is transparent regarding execution success and preserves error propagation: It captures the exit status of the wrapped command and returns it as its own exit code. This ensures that if a command fails, any subsequent logic in your shell script (e.g., `bx cmd || handle_error`) will correctly receive the failure signal.

If no command arguments are provided, `bx` exits with status 1 and the error message `Error: No command provided.`

## Examples

**1. Basic Command Execution**
Transforming a standard directory listing into a structured Markdown block:
```bash
$ bx ls -la
```
**Output:**
```bash
$ ls -la
total 16
drwxr-xr-x  3 user user 4096 Oct 25 10:00 .
drwxr-xr-x  2 user user 4096 Oct 25 09:00 ..
```
🐚

**2. Errors are captured in the fence with a warning prefix**
stderr from the wrapped command is captured, prefixed with `⚠️`, and included inside the fence on stdout:
```bash
$ bx non_existent_command
```
**Output (stdout):**
```bash
$ non_existent_command
⚠️ /bin/bash: line 1: non_existent_command: command not found
```
🐚

**3. Plain mode (no fences)**
Use `-p` to suppress the Markdown fences when the output does not need them:
```bash
$ bx -p ls
file1.txt
file2.sh
```
🐚

**4. The "Injection" Pattern (Automation)**
Provide structured system context to a subsequent `ask` query via the pipeline:
```bash
# Use bx to capture dmesg, then ask an LLM to interpret it
bx sudo dmesg | tail -n 20 | help "Are there any hardware disconnect events?" | answer
```
