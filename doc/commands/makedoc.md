# makedoc

**`makedoc`** is a documentation orchestration utility designed to maintain consistency across the Answer toolchain documentation. It automates the generation of standardized Markdown (`.md`) files in the `doc/` directory by parsing structured comment blocks embedded directly within shell scripts or configuration templates. 

By using `makedoc`, developers ensure that changes to command flags, environment variables, or syntax descriptions in the source code are reflected in the user documentation with minimal manual effort and zero formatting drift.

## Synopsis

```bash
makedoc [OPTIONS] <path>...
```

The path can be a specific file, a directory of scripts (e.g., `bin/commands`), or multiple sources separated by spaces.

## Description

`makedoc` scans the provided files for specialized "docstring" comments that follow a structured syntax. Once it identifies these blocks, it parses the metadata to generate human-readable Markdown documentation formatted according to project standards. 

The utility is designed for a **source-of-truth** workflow: instead of maintaining separate `.md` files and code implementation in two places, developers write documentation directly above their function definitions or command logic within shell scripts using specific annotation prefixes (e.g., `@description`, `@usage`, `--flag`). This minimizes the risk of "documentation rot" where the help menu shows one behavior while the script implements another.

## Options

| Flag | Long form | Description |
|------|-----------|-------------|
| `-o` | `--output <dir>` | **Target Directory:** Specifies the directory where generated `.md` files will be written. Defaults to `doc/commands`. If specified, existing files in that directory are not deleted unless `--force` is used. |
| `-f` | `--force`   | **Overwrite Mode:** Silently overwrites any existing documentation files with updated versions from the source scripts. |
| `-t` | `--template <file>` | **Template Injection:** Uses a specified Markdown template to control the visual structure and branding of the generated output. |
| `--help` |           | Print usage information and exit. |

## Input Modes

The behavior of `makedoc` depends on the types of files provided as arguments:

| Condition | Behavior | Resulting Output Format |
|-----------|----------|-------------------------|
| **Shell Scripts (`.sh`)** | Scans for comment blocks prefixed with `@description`, `@usage`, or `--flag`. | Generates `.md` files corresponding to the primary function name found in the script. |
| **Config Files (YAML/JSON)** | Parses key-value pairs and structural metadata into a structured "Configuration" section. | Generates technical reference documentation for environment variables or tool settings. |

## Examples

**1. Standard Documentation Generation**
Automatically generate all command documentation from your `bin/commands` directory:
```bash
$ makedoc bin/commands
# This will scan every .sh file and create matching files in doc/commands/
```

**2. Targeted Output to a Custom Directory**
Generate a dedicated "API reference" folder for external developers without cluttering the main `doc/` directory:
```bash
$ makedoc --output docs/api bin/commands
```

**3. Forcing an Update (CI/CD Workflow)**
Use `--force` in automated pipelines to ensure documentation is always kept up-to-date with every commit during the build process:
```bash
# Automatically update all command docs without manual confirmation
$ makedoc --output doc/commands bin/commands/*.sh --force
```

**4. Using a Custom Design Template**
Apply specialized formatting (like adding headers or specific warning blocks) using a custom template file:
```bash
$ makedoc --template templates/professional_style.md bin/commands/model.sh
```
