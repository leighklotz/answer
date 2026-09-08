# gx

`gx` emits two versions of a file for comparison: the version from a specified Git revision (defaulting to `HEAD`) and the current working-tree version. 

Each output is wrapped in Markdown code blocks via `bx`, making it suitable as input for commands like `dreck`.

## Synopsis

    gx [REV] FILE

* **`REV`**: The Git revision to compare against (e.g., a commit hash, branch name, or `HEAD~1`). Defaults to `HEAD`.
* **`FILE`**: The path to the file relative to the repository root.

**Requirements:**
- Must be run within a Git repository.
- Specified `FILE` must exist in your working tree as a regular file.

## Examples

Compare the current file with its state at `HEAD`:

    gx start-llama-server.sh | dreck

Compare the current file with an older revision:

    gx HEAD~3 start-llama-server.sh | dreck
