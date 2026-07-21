# makedoc

**`makedoc`** is a documentation orchestration utility designed to maintain consistency across the Answer toolchain documentation. It automates the generation of standardized Markdown (`.md`) files in the `doc/` directory by parsing structured comment blocks embedded directly within shell scripts or configuration templates. 

By using `makedoc`, developers ensure that changes to command flags, environment variables, or syntax descriptions in the source code are reflected in the user documentation with minimal manual effort and zero formatting drift.

## Synopsis

```bash
makedoc [OPTIONS] <source_files|directory>...
```

The first non-flag argument specifies the target files or directory containing scripts to document.

## Description

`makedoc` implements a "Source of Truth" workflow for technical writing. Instead of manually maintaining separate `.md` files, developers annotate their shell functions and script headers with structured doc-tags (e.g., `# @synopsis`, `# @options`). `makedoc` parses these tags and applies them to predefined Markdown templates to produce the uniform documentation seen in the `/doc` directory.

### The Parsing Engine
The utility scans source files for **Doc Blocks**—commented sections delimited by specific markers. It specifically looks for:
*   **Metadata:** `@name`, `@description`.
*   **Structure:** `@synopsis`, `@options`, `@examples`, and `@notes`.
* **Data Tables:** Uses structured key-value pairs within the comment block to automatically construct Markdown tables (e.g., Flag, Long Form, Description).

### Documentation Lifecycle
1.  **Discovery:** The tool identifies all relevant `.sh` or `.md` files in the provided path.
2.  **Extraction:** It extracts metadata and structured content from tagged blocks while ignoring standard functional comments.
3.  **Validation:** It verifies that every command documented has a corresponding entry in its primary implementation script to prevent "stale" documentation.
4.  **Rendering:** The extracted data is injected into templates (like those used for `ask.md` or `answer.md`) and written as `.md` files.

## Options

| Flag | Long form | Description |
|------|-----------|------------------------------------------------------------------------------------------------|
| `-s` | `--source` | Specify a specific directory to scan for source scripts (Default: current project root). |
| `-o` | `--output`  | The destination directory where generated documentation will be saved. Defaults to `doc/`. |
| `-t` | `--template` | Specifies which template style to use (e.g., `standard`, `command-reference`, or `manual`). |
| `-d` | `--dry-run`| Renders the final Markdown content directly to **stdout** without writing any files to disk. |
| `--validate` |       | Runs a consistency check between documented flags and actual code implementation. Exits with error if mismatches are found. |

## Output Modes

The output format of `makedoc` depends on whether it is being used as an interactive utility or part of a CI/CD pipeline:

| Mode | Context | stdout | stderr |
|------|---------|--------|--------|
| **Standard** (File) | Running the command locally to update docs. | Progress logs and completion summary. | Error messages, warnings about missing tags, and validation failures. |
| **Dry-Run** (`--dry-run`) | Testing a new template or inspecting changes before committing. | The raw Markdown content of all generated files. | N/A |
| **CI Mode** (Exit Code) | Used in automated testing pipelines to ensure docs are up to date. | Silence (unless errors occur). | Error logs for failed validation checks. |

## Examples

**1. Bulk Documentation Generation**
Generate updated documentation files for all scripts located in the `bin/` directory:
```bash
$ makedoc bin/
```

**2. Targeted Template Preview**
Preview how a specific script would look if it were documented using a custom "minimalist" template, without writing to disk:
```bash
$ makedoc tools.sh --template minimalist --dry-run
```

**3. Documentation Validation in CI**
Run the documentation generator as part of a Git pre-commit hook or GitHub Action to ensure all new commands are documented and valid:
```bash
# Fails if any command has undocumented flags (via validation engine)
$ makedoc . --validate && git commit -m "Update logic" || echo "Documentation mismatch detected!"
```
