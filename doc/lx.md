# lx.sh Usage Documentation

`lx.sh` is a utility designed to wrap file contents in Markdown fenced code blocks, making it ideal for preparing snippets for documentation or LLM prompts. It handles language detection automatically and supports custom headers and footers.

## Syntax
```bash
lx.sh [--before=STR] [--after=STR] [files...]
```

## Description
The script reads file paths from command-line arguments or from `stdin` (one path per line). It identifies the programming language based on the file extension, wraps the content in appropriate Markdown code fences, and injects metadata using customizable headers (`--before`) and footers (`--after`).

### Features
* **Automatic Language Detection:** Uses common file extensions to determine syntax highlighting tags (e.g., `.py` $\rightarrow$ `python`, `.sh` $\rightarrow$ `bash`).
* **Flexible Input:** Accepts direct file arguments, a list of files via pipes, or interactive input from `stdin`.
* **Placeholder Support:** Use special placeholders in `--before` to inject filenames and detected languages.
* **Escape Sequence Support:** Since the script uses `printf %b`, you can use escape sequences like `\n` in your custom strings to insert newlines.
* **Robustness:** Gracefully skips directories, non-regular files, unreadable files, or missing files without stopping the entire process.

## Options

| Option | Description |
| :--- | :--- |
| `--before=STR` | A custom string to print before each code block. Use placeholders `{filename}` and `{language}` for dynamic content. Supports `\n`. |
| `--after=STR` | A custom string to print after each code block (e.g., closing fences or separators). Supports `\n`. |
| `--help` | Displays the usage information. |

### Placeholders (for `--before`)
* `{filename}`: The name/path of the current file being processed.
* `{language}`: The detected programming language name (e.g., `javascript`, `rust`).

## Default Behavior
If no options are provided, the script uses these defaults for every file:

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

## Examples

**1. Basic usage with multiple files as arguments:**
```bash
./lx.sh script.py main.js README.md
```

**2. Using `stdin` (e.g., from a find command):**
```bash
find . -name "*.go" | ./lx.sh
```

**3. Customizing the header with placeholders and newlines:**
```bash
./lx.sh --before="### File: {filename}\nLanguage: `{language}`\n--- \n" script.rb
```

**4. Adding a custom footer to separate blocks clearly:**
```bash
./lx.sh --after="\n\x60\x60\x60\n---\n" config.yaml
```

**5. Piping output directly into another command (e.g., an LLM tool):**
```bash
cat error.log | ./lx.sh --before="Context: {filename}" | ask "What caused this?"
```
