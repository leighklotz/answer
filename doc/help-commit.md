<<<<<<< HEAD
=======
# help-commit

**help-commit** is a specialized utility in the Answer framework that automates the generation and execution of `git commit` commands. It analyzes your current git state—including working directory, repository root, and file changes—using an LLM and produces a `git commit` command following the Conventional Commits specification.

## Synopsis

```bash
help-commit [git diff options] [--] [ask options]
```

## Description

The command performs the following workflow:
1. **Environment Check:** Verifies that the current working directory is inside a Git repository.
2. **Context Gathering:** Executes a series of `bx` wrapped commands to collect state:
    * `pwd`
    * `git rev-parse --show-toplevel`
    * `git diff --stat --no-merges [options]`
    * `git diff --numstat [options]`
    * `git diff [options]`
    * `git diff --cached [options]`
3. **Inference:** Pipes the structured git context to `ask` with a specialized prompt instructing the LLM to output a `git commit` command.
4. **Extraction & Execution:** Uses `answer` to extract the text, `unfence` to strip markdown, and `bash` to execute the generated command.

If the LLM determines it lacks sufficient information to write a meaningful commit message and needs more data, it will instead output a request for further git results.

## Options

| Flag | Long form | Description |
|------|-----------|-------------|
| `--help` | | Print usage information and exit. |
| `--quiet` | `-q` | Suppress the introductory message. |
| `--` | | **Separator:** All arguments following this flag are passed directly to the underlying `ask` command. |
| `[git diff options]` | | Arguments provided before the `--` separator are passed to the `git diff` commands used during context gathering. |

## Examples

**1. Standard Usage**
Analyze the current state and prompt for a commit command.
```bash
$ help-commit
```

**2. Passing Arguments to Git Diff**
If you want to limit the scope of the diff analysis to specific files or patterns:
```bash
$ help-commit src/*.py
```

**3. Passing Arguments to the LLM (via `--`)**
Use the separator to pass specific instructions or options to the `ask` stage.
```bash
$ help-commit -- -i "Please use emojis in the commit messages"
```

**4. Quiet Mode**
Run without the introductory message.
```bash
$ help-commit --quiet
# OR
$ help-commit -q
```

## Exit Codes

* **0:** Success (The command was executed or the LLM requested more info).
* **1:** Failure (Not in a git repository or an error occurred during the pipeline).
>>>>>>> newdoc
