# help-commit

**help-commit** is a specialized utility in the Answer framework that automates the generation and execution of `git commit` commands by analyzing your current Git state. It uses an LLM to interpret staged changes, unstaged modifications, and provided context (via pipes or arguments) to produce descriptive messages following the Conventional Commits specification.

## Synopsis

```bash
help-commit [OPTIONS] [[git diff options]] [-- ASK_ARGUMENTS ]
```

The command performs a high-precision workflow:
1.  **Environment Check:** Verifies that you are inside a Git repository; exits if not.
2.  **Context Synthesis:** Gathers comprehensive project state—including the current branch, `pwd`, and detailed diffs of staged/unstaged changes using the `bx` wrapper to ensure structured Markdown context is provided to the LLM. If piped input is detected (e.g., via a file or command), it incorporates that as additional semantic context.
3.  **Inference:** Passes this synthesized payload through a specialized prompt to an LLM via the `ask` engine. 
4.  **Safety-Gated Execution:** Parses the response for generated git commands, extracts them using `unfence`, and presents the proposed command(s) in an interactive safety gate (via a pager/confirmation prompt). The user must confirm (`y`) before the commands are executed in the shell.

## Options

| Flag | Long form | Description |
|------|-----------|-------------|
| `--help` | | Print usage information and exit. |
| `-q` | `--quiet` | Suppress introductory messages (sets internal quiet mode). |
| `--` | **Separator:** Everything following this separator is passed as arguments to the underlying `ask` command, allowing you to provide additional instructions or constraints for the LLM prompt. |

### Positional Arguments

*   **[git diff options]**: Any flags provided *before* the `--` separator are appended as arguments to the internal `git diff` commands (e.g., targeting specific file paths).
*   **[ask arguments/options]**: Any text following the `--` is passed directly into the context for the LLM via `ask`. Use this to refine style, tone, or detail level.

## Examples

**1. Standard Usage (Autonomous)**
Analyze all current changes in the repository and suggest a conventional commit:
```bash
$ help-commit
```

**2. Scoped Analysis**
Only analyze changes within a specific directory to limit the diff context provided to the LLM:
```bash
$ help-commit src/
```

**3. Refining with Custom Instructions (via `--`)**
Use the separator to pass instructions that refine how the model structures or writes the message:
```bash
# Instructs the LLM via additional prompt parameters to use a specific tone
$ help-commit -- "-i Use a very descriptive, professional tone and follow Conventional Commits"

# Provide flags for 'ask' directly after the separator (e.g., Observation Mode)
$ help-commit -t "Should I include a summary of technical changes in the body?"
```

**4. Contextualized Commit (Piped Input)**
Pipe specific text or logs into `help-commit` to provide extra information that isn't visible in a standard `git diff`:
```bash
# Use a task list from a file as additional context for why changes were made
$ cat TODO.md | help-commit

# Combine current git status with recent system logs to guide the commit message
$ tail -n 20 /var/log/syslog | help-commit -- "-i Contextualize based on these log events"
```

**5. Quiet Mode**
Run the process without unnecessary output:
```bash
$ help-commit --quiet
```

## Exit Codes

| Code | Meaning |
| :--- | :--- |
| **0** | Success (The command was generated, presented for confirmation, and/or executed). |
| **1** | Failure (Not in a Git repository, an error occurred during execution, or arguments were invalid). |
