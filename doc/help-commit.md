# doc/help-commit.md

# help-commit

**help-commit** is a specialized utility in the Answer framework that automates the generation of `git commit` commands by analyzing your current Git state. It uses an LLM to interpret staged and unstaged changes, producing descriptive commit messages following the Conventional Commits specification.

## Synopsis

```bash
help-commit [--help] | [--quiet] [git diff options] -- [ask arguments/options]
```

## Description

The command performs the following workflow:

1.  **Environment Check:** Verifies that the current working directory is inside a Git repository; exits with an error if not.
2.  **Context Gathering:** Collects comprehensive project state via several git-related commands, including `pwd`, `git rev-parse --show-toplevel`, and multiple forms of `git diff` (stat, numstat, staged/cached changes). Most outputs are wrapped in Markdown code fences using `bx` to ensure the LLM receives structured context.
3.  **Inference:** Passes this Git context through a specialized prompt to an LLM. The model is instructed to output a single, specific `git commit` command (or multiple commands for independent changes) using conventional commit standards and avoiding generic messages like `git add .`.
4.  **Extraction & Execution:** Strips Markdown formatting via `unfence`, extracts the code block, and executes the resulting git commands directly in your shell using `bash`.

## Options

| Flag | Long form | Description |
|------|-----------|-------------|
| `--help` | | Print usage information and exit. |
| `-q` | `--quiet` | Suppress introductory messages (sets internal quiet mode). |
| `--` | | **Separator:** All arguments following this flag are treated as positional parameters to be passed into the `ask` component via an attachment (`-i`). This allows you to provide additional instructions or constraints to the LLM. |

### Positional Arguments

*   **[git diff options]**: Any flags provided before the `--` separator (e.g., specific file paths) are appended as arguments to the internal `git diff` commands used during context gathering.
*   **[ask options]**: Any content following the `--` is treated by the underlying `ask` command as an attachment (`-i`), allowing you to refine how the LLM generates your commit (e.g., `-- -i "Use emojis"`).

## Examples

**1. Standard Usage**
Analyze all current changes and suggest a conventional commit:
```bash
$ help-commit
```

**2. Limiting Scope with Git Diff Options**
Only analyze changes in the `src/` directory for the diff context:
```bash
$ help-commit src/
```

**3. Passing Instructions to the LLM (via `--`)**
Use the separator to pass specific instructions or attachment parameters directly to the reasoning engine:
```bash
# This instructs the LLM via an 'attachment' style input through ask -i
$ help-commit -- "-i Use a very descriptive and professional tone"

# You can also provide flags that become arguments for 'ask'
$ help-commit src/ -- -t "What exactly did I change in these files?"
```

**4. Quiet Mode**
Run the process without unnecessary output:
```bash
$ help-commit --quiet
```

## Exit Codes

*   **0:** Success (The command was generated and executed, or more information was requested by the LLM).
*   **1:** Failure (Not in a Git repository, an error occurred during execution, or an invalid argument was provided).
