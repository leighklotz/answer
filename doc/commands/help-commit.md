# help-commit

**help-commit** is a specialized utility in the Answer framework that automates the generation and execution of `git commit` commands by analyzing your current Git state. It uses an LLM to interpret staged changes, unstaged modifications, and provided context (via arguments) to produce descriptive commit messages using imperative-mood summaries and bulleted detail lines.

## Synopsis

```bash
help-commit [--help] | [--quiet] [--dry-run | -n] [git diff options] [--] [ask options]
```

The command performs a high-precision workflow:
1.  **Environment Check:** Verifies that you are inside a Git repository; exits if not.
2.  **Context Synthesis:** Gathers comprehensive project state—including the current PWD, repository root, branch, and detailed diffs of staged/unstaged changes using the `bx` wrapper to ensure structured Markdown context is provided to the LLM.
3.  **Inference:** Passes this synthesized payload through a specialized prompt to an LLM via the `ask` engine.
4.  **Safety-Gated Execution:** Parses the response for generated git commands, extracts them using `unfence`, and presents the proposed command(s) in an interactive safety gate (via a pager/confirmation prompt). The user must confirm (`y`) before the commands are executed in the shell. In `--dry-run` mode, the raw output is displayed without extraction or execution.

## Options

| Flag | Long form | Description |
|------|-----------|-------------|
| `--help` | | Print usage information and exit. |
| `-q` | `--quiet` | Suppress introductory messages (sets internal quiet mode). |
| `-n` | `--dry-run` | Display the generated output without executing the git commands (skips `unfence` and `bash`). |
| `--` | **Separator:** Everything following this separator is given as parameters for the LLM context (e.g., `main..HEAD`). |

### Positional Arguments

*   **[git diff options]**: Any flags provided *before* the `--` separator are appended as arguments to the internal `git diff` commands (e.g., targeting specific file paths).
*   **[ask options]**: Any text following the `--` is passed directly as parameters for the LLM context via `ask`. Use this to provide range references or additional context (e.g., `main..HEAD`).

## Examples

**1. Standard Usage (Autonomous)**
Analyze all current changes in the repository and generate commit commands:
```bash
$ help-commit
```

**2. Scoped Analysis**
Only analyze changes within a specific directory to limit the diff context provided to the LLM:
```bash
$ help-commit src/
```

**3. Providing Context via `--`**
Use the separator to pass context parameters to the LLM:
```bash
# Provide a diff range for context
$ help-commit -- main..HEAD
```

**4. Dry Run**
Preview the generated commands without executing them:
```bash
$ help-commit --dry-run
```

**5. Quiet Mode**
Run the process without unnecessary output:
```bash
$ help-commit --quiet
```

## Exit Codes

| Code | Meaning |
| :--- | :--- |
| **0** | Success (commands generated and executed, or no changes detected). |
| **1** | Failure (not in a Git repository, an error occurred during execution, or arguments were invalid). |
