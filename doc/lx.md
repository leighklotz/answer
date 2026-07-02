# `lx.sh` Usage Documentation

`lx.sh` is a utility designed to print the contents of files wrapped in Markdown fenced code blocks, making it ideal for preparing code snippets for documentation or LLM prompts.

## Syntax
```bash
lx.sh [--before=STR] [--after=STR] [files...]
```

## Description
The script reads file paths from command-line arguments or from `stdin` (one path per line). It attempts to identify the programming language based on the file extension and wraps the content in appropriate Markdown code fences.

### Features
* **Automatic Language Detection:** Uses file extensions to determine the language (e.g., `.py` $\rightarrow$ `python`, `.sh` $\rightarrow$ `bash`).
* **Flexible Input:** Accepts direct file arguments or piped input from `stdin`.
* **Placeholder Support:** Use placeholders in the `--before` string to dynamically inject metadata.
* **Robustness:** Skips non-existent files, directories, and unreadable files.

## Options

| Option | Description |
| :--- | :--- |
| `--before=STR` | Custom string to print before the code block. |
| `--after=STR` | Custom string to print after the code block. |
| `--help` | Displays the usage information. |

### Placeholders (for `--before`)
* `{filename}`: The path/name of the current file.
* `{language}`: The detected language name.

## Default Behavior
If no options are provided:
* **Default `--before`:** `# file {filename}` followed by a newline and ` ```{language}`
* **Default `--after`:** ` ``` ` followed by a newline and `---`

## Examples

**1. Basic usage with files as arguments:**
```bash
./lx.sh script.py main.js README.md
```

**2. Using `stdin` for multiple files:**
```bash
find . -name "*.py" | ./lx.sh
```

**3. Customizing the header with placeholders:**
```bash
./lx.sh --before="### File: {filename} ({language})" script.rb
```

**4. Customizing both header and footer:**
```bash
./lx.sh --before="START\n\n" --after="\n\nEND" config.yaml
```
