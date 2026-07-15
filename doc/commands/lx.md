# lx

**lx** is a file-ingestion utility within the Answer framework that streams target files into your pipeline, automatically wrapping them in clean Markdown code blocks for downstream parsing by tools like `ask` or `help`. It is designed to provide well-formatted context from multiple files simultaneously.

## Synopsis

```bash
lx [OPTIONS] [files...]
```

The command accepts file paths as positional arguments or reads a list of paths via standard input (`stdin`).

## Description

**lx** automates the process of preparing code snippets and documentation for LLM consumption. It identifies programming languages based on file extensions, wraps content in appropriate Markdown syntax fences, and injects metadata using customizable headers and footers. This ensures that when files are piped into an `ask` or `help` command, the model receives structured context rather than raw text blocks.

### Features
* **Automatic Language Detection:** Uses common file extensions to determine syntax highlighting tags (e.g., `.py` $\rightarrow$ `python`, `.sh` $\rightarrow$ `bash`).
* **Flexible Input:** Accepts direct file arguments, a list of files via pipes, or interactive input from `stdin`.
* **Placeholder Support:** Use special placeholders in `--before` to inject filenames and detected languages dynamically.
* **Escape Sequence Support:** Supports escape sequences (like `\n`) within custom headers/footers using `printf %b` logic.
* **Robustness:** Gracefully skips directories, non-regular files, unreadable files, or missing files without interrupting the stream.

## Options

| Flag | Long form | Description |
|------|-----------|-------------|
| `--before=STR` | | A custom string to print before each code block. Use placeholders `{filename}` and `{language}` for dynamic content (e.g., `### File: {filename}`). Supports `\n`. |
| `--after=STR` | | A custom string to print after each code block. Useful for adding separators or closing fences manually. |
| `--help` | | Displays the usage information and exits. |

### Placeholders (for `--before`)
* `{filename}`: The name/path of the current file being processed.
* `{language}`: The detected programming language tag (e.g., `python`, `javascript`).

## Default Behavior

If no options are provided, **lx** uses these defaults for every file in the stream:

**Default `--before`:**
```markdown
# file <filename>
```{language}
```
*(Note: A newline is added after the filename and language tag)*

**Default `--after`:**
```markdown
```
---
```

## Examples

**1. Basic usage with multiple files as arguments:**
Stream several source files into an LLM query to ask for a refactor.
```bash
$ lx script.py main.js README.md | help "Refactor these modules"
```

**2. Using `stdin` (e.g., from a file list):**
Pipe a list of specific log files into the utility.
```bash
find ./logs -name "*.log" | lx
```

**3. Customizing headers with placeholders:**
Generate highly structured documentation blocks by injecting filenames and language tags dynamically.
```bash
$ lx --before="### File: {filename}\nLanguage: `{language}`\n--- \n" script.rb
```

**4. Adding a custom footer to separate content blocks:**
Use `--after` to ensure every code block is clearly demarcated in the resulting stream.
```bash
$ lx --after="\n\`\`\`\n---\n" config.yaml
```

**5. Preparing context for an LLM pipeline:**
Combine `lx` with a question to provide immediate, well-formatted assistance.
```bash
$ cat error.log | lx --before="Log Context:" | ask "Explain these errors."
```
