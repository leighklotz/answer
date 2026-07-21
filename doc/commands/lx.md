# lx

**`lx`** is the **Context Ingestor** of the Answer framework. It streams target files into a pipeline, automatically wrapping their content in Markdown code fences with appropriate language tags and metadata headers. This ensures that when multiple files are piped into an `ask`, `help`, or `bx` command, they arrive as structured, machine-readable context rather than raw text blocks, allowing the LLM to distinguish between different file contents easily.

## Synopsis

```bash
lx [OPTIONS] [files...]
```

The command accepts file paths as positional arguments or reads a list of paths via standard input (`stdin`). It uses the 📥 icon in terminal output and pipeline headers to signify ingestion.

## Description

**`lx`** automates the preparation of source code, configuration files, and documentation for LLM consumption. By converting raw files into structured Markdown blocks, it solves the problem of "context collision," where an LLM might otherwise confuse multiple input files or fail to identify which programming language is being provided in a large stream.

### Key Features
* **Automatic Language Detection:** Leverages file extensions to determine syntax highlighting tags (e.g., `.py` $\rightarrow$ `python`, `.sh` $\rightarrow$ `bash`).
* **Flexible Input Streams:** Supports direct command-line arguments, piping from other commands (`find | lx`), or reading filenames via `stdin`.
* **Dynamic Placeholders:** Uses `{filename}` and `{language}` placeholders in custom headers to inject real-time metadata into the stream.
* **Markdown Orchestration:** Automatically handles fence opening/closing and provides customizable delimiters using `--before` and `--after` options.
* **Resilient Processing:** Gracefully skips directories, special files (like devices), or unreadable files without breaking the pipeline execution.

## Options

| Flag | Long form | Description |
|------|-----------|-------------|
| `--before=STR` | | A custom string to print before each code block. Supports placeholders `{filename}` and `{language}`, and escape sequences (e.g., `\n`). Example: `### File: {filename} \n ```{language}` |
| `--after=STR`  | | A custom string to print after each code block. Useful for adding separators or manual closing fences if needed. Defaults to a standard Markdown close and separator. |
| `--help`        | | Displays the usage information and exits. |

### Placeholders (for `--before`)
* `{filename}`: The relative path/name of the file being processed.
* `{language}`: The detected programming language tag used for syntax highlighting.

## Default Behavior

If no options are provided, **`lx`** wraps every file in a standard Markdown block to ensure clean parsing by downstream tools like `unfence`:

**Default `--before`:**
```markdown
# file <filename>
```{language}
```
*(A newline is automatically added after the filename and language tag)*

**Default `--after`:**
```markdown
```
---
```

## Input Modes

| Condition | Behavior |
|-----------|----------|
| **Arguments** | `lx file1.py file2.sh` treats each as a unique source to be wrapped. |
| **Piped (`stdin`)** | Reads filenames from the pipe (e.g., `find . -name "*.js" | lx`). Each line is treated as a file path to process. |

## Examples

**1. Multi-File Context Ingestion**
Stream multiple files into an LLM query to perform cross-file analysis or refactoring.
```bash
$ lx config.yaml database.py logic.sh | help "Explain how these three files interact"
```

**2. Custom Header Injection (Highly Structured)**
Use placeholders to create a professional, highly readable context format for complex code reviews.
```bash
$ lx --before="📂 **Source:** `{filename}`\n**Language:** `{language}`\n---\n```{language}" script.py main.js | help "Identify potential bugs"
```

**3. Piping from Shell Utilities**
Use `find` or `grep` to selectively ingest specific files into a pipeline.
```bash
$ find ./src -name "*.go" | lx | ask "Summarize the architecture of this package."
```

**4. Adding Delimiters for Visual Separation**
Ensure that long outputs from multiple tools are clearly demarcated in the resulting conversation history using `--after`.
```bash
# Use --after to add a clear visual separator between files and subsequent output
$ lx script.js utils.py | help "Refactor these" --after="\n\`\`\`\n--- \n"
```
