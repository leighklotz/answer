# help-commit

**help-commit** is a specialized utility in the Answer framework that automates the generation and execution of `git commit` commands by analyzing your current Git state. It uses an LLM to interpret staged and unstaged changes, producing descriptive messages following the Conventional Commits specification.

## Synopsis

```bash
help-commit [--help] | [--quiet] [git diff options] -- [ask arguments/options]
```

The command performs a high-precision workflow:
1.  **Environment Check:** Verifies that you are inside a Git repository; exits if not.
2.  **Context Gathering:** Collects comprehensive project state (including `pwd`, current branch, and multiple forms of `git diff`) using the `bx` wrapper to ensure the LLM receives structured Markdown context.
3.  **Inference:** Passes this context through a specialized prompt to an LLM via the `ask` command. 
4.  **Extraction & Execution:** Parses the LLM's response for code blocks, extracts them using `unfence`, and executes the resulting git commands directly in your shell.

## Options

| Flag | Long form | Description |
|------|-----------|-------------|
| `--help` | | Print usage information and exit. |
| `-q` | `--quiet` | Suppress introductory messages (sets internal quiet mode). |
| `--` | **Separator:** Everything following this separator is passed as arguments to the underlying `ask` command. This allows you to provide additional instructions or constraints for the LLM prompt. |

### Positional Arguments

*   **[git diff options]**: Any flags provided *before* the `--` separator are appended as arguments to the internal `git diff` commands (e.g., specific file paths).
*   **[ask arguments/options]**: Any text following the `--` is passed directly into the `ask` component. Use this to refine the LLM's behavior or provide context-specific constraints for the commit message.

## Examples

**1. Standard Usage**
Analyze all current changes and suggest a conventional commit:
```bash
$ help-commit
```

**2. Limiting Scope with Git Diff Options**
Only analyze changes in a specific directory to limit the diff context provided to the LLM:
```bash
$ help-commit src/
```

**3. Refining the Commit Message (via `--`)**
Use the separator to pass instructions that refine how `ask` interprets your changes. The text following `--` is passed as arguments to the underlying reasoning engine:
```bash
# This instructs the LLM via additional prompt parameters 
$ help-commit -- "-i Use a very descriptive and professional tone"

# You can also provide flags for 'ask' directly after the separator
$ help-commit src/ -- -t "Include info about why these changes were made?"
```

**4. Quiet Mode**
Run the process without unnecessary output:
```bash
$ help-commit --quiet
```

## Exit Codes

*   **0:** Success (The command was generated and executed, or more information/confirmation was requested from the user).
*   **1:** Failure (Not in a Git repository, an error occurred during execution, or invalid arguments were provided).
