# cx

**`cx`** is the **stdin Context Concatenator** of the Hallux toolchain, completing the ingestion family (`lx`, `bx`, `cx`). It reads a **list of filenames from standard input** — one per line — and streams the *contents* of those files to standard output as structured context blocks in the LX format. It is the stream-oriented counterpart to `lx`: instead of naming files as arguments, you feed `cx` from any list producer (`find`, `git ls-files`, `rg --files`, `fd`, `grep -l`, a saved manifest), making it the natural final ingestion stage before an `ask`/`help` call.

## Synopsis

```bash
cx [-n|--line-numbers] [-0|--null] [-u|--unique] [-s|--strict] \
   [--before=STR] [--after=STR] [--base=DIR] [--help]
```

`cx` accepts **no positional file arguments** — the filename list must arrive on `stdin`. An empty list produces empty output and exit status 0.

## Description

`cx` is to file *lists* what `cat` is to files — except the output is structured for LLM consumption. Because the list itself is data flowing through a pipe, `cx` treats it defensively: lines are trimmed, blank lines and `#` comments are ignored, and duplicate paths can be collapsed, so lists assembled with `cat`, `grep`, `sort -u`, or brace groups ingest cleanly.

Each accepted entry is emitted as one LX-format block, **byte-for-byte identical** to what `lx` emits. Downstream consumers (`ask`, `help`, anything that parses LX context) cannot tell the two tools apart, and their outputs can be freely concatenated inside a single prompt.

### Key Features
* **Stdin-native ingestion:** filenames in on `stdin`, file contents out on `stdout`. `cx` never reads file *content* from stdin — only the list (see Gotchas).
* **Streaming:** entries are processed as they arrive; `cx` begins emitting before the producer finishes and uses constant memory regardless of list length.
* **List hygiene (newline mode):** surrounding whitespace is trimmed, blank lines are skipped, `#`-prefixed comment lines are ignored, and trailing CR characters are stripped — CRLF lists and annotated manifests "just work".
* **NUL-safe mode:** `-0` accepts `find -print0`-style input verbatim, handling filenames that contain newlines, `#`, or leading/trailing spaces.
* **Automatic language detection:** the same lower-cased extension table as `lx` selects the fence tag (`.py` → `python`, `.sh` → `bash`); unknown extensions get an untagged fence.
* **Resilient by default, strict on demand:** missing, unreadable, or non-regular entries produce a `⚠️` warning on stderr and are skipped; `--strict` turns them into a fatal `⛔` error with exit status 1 — for CI flows where a stale list must fail loudly rather than silently shrink the context.
* **Order-preserving dedup:** `-u`/`--unique` drops paths already emitted earlier in the stream, so merged/overlapping discovery results never duplicate blocks.

## Options

| Flag | Long form | Description |
|------|-----------|-------------|
| `-n` | `--line-numbers` | Prepend line numbers to file contents by passing `-n` to `cat`, as with `lx`. |
| `-0` | `--null` | Read NUL-delimited filenames instead of newline-delimited. Pairs with `find -print0` / `rg --files -0`. Names are taken verbatim: no trimming, no comment or blank-line handling. |
| `-u` | `--unique` | Skip a path that has already been emitted earlier in the stream. First occurrence wins; duplicates are counted in the stderr summary. |
| `-s` | `--strict` | Treat missing, unreadable, or non-regular entries as fatal: print a `⛔` error to stderr and exit 1 immediately. Default behavior is warn (`⚠️`) and skip. |
| | `--before=STR` | Custom string printed before each block. Supports `{filename}` and `{language}` placeholders and `\n`-style escapes (interpreted via `printf '%b'`). Same semantics as `lx`; defaults to the standard `# file {filename}` header plus quad-backtick fence with language tag. |
| | `--after=STR` | Custom string printed after each block; escapes interpreted, no placeholders. Defaults to the fence close plus the `---` separator. |
| | `--base=DIR` | Resolve *relative* paths against `DIR` instead of the current directory (for lists generated elsewhere). The `# file` header still shows the path exactly as it appeared in the list. |
| | `--help` | Show usage and exit. |

### Placeholders (for `--before`)
* `{filename}` — the path exactly as read from the list (`--base` affects reading only, never display).
* `{language}` — the detected language tag.

Placeholders are expanded only in `--before`; `--after` is printed verbatim apart from backslash escapes.

## List Format

The stdin grammar depends on the delimiter mode:

| | Newline mode (default) | NUL mode (`-0`) |
|---|---|---|
| Separator | newline | NUL byte |
| Trimming | leading/trailing whitespace stripped | none (verbatim) |
| Blank entries | skipped | skipped |
| `#` comments | skipped | not applicable |
| CR handling | trailing `\r` stripped | none |

Example of a generated/annotated list in newline mode:

```text
# Changed in this PR — produced by ci/changed-files.sh
src/api/router.py
src/api/auth.py

# docs
README.md
```

Consequence: a filename that *begins* with `#` cannot be expressed in newline mode — use `-0` for such paths.

## Output Format

Each accepted entry produces exactly one block; blocks are emitted back-to-back with no separator beyond the trailing `---` line (which is part of the default `--after`):

    # file src/main.py
    ````python
    def main():
        print("hello")
    ````
    ---

Notes:
* The fence uses **four backticks** so file content that itself contains triple-backtick Markdown fences (e.g., documentation) remains intact.
* The final block is also terminated by `---`, matching `lx`.
* After the last block, `cx` writes a one-line summary to **stderr**:

```text
🔗 cx: 3 ingested, 1 skipped, 0 duplicates (18.4 KiB)
```

## `cx` vs `lx`

| Dimension | `lx` | `cx` |
|---|---|---|
| File list source | positional arguments (stdin fallback in pipes) | `stdin` only — required |
| Bad entry | error → exit 1 (pipeline halts) | warn + skip; `--strict` restores fail-fast |
| NUL-delimited names | not supported | `-0` |
| Comments / blank lines in list | n/a (arguments) | skipped |
| Duplicate paths | emitted each time | `--unique` collapses |
| Output format | LX blocks | identical LX blocks |

## Error Handling & Exit Code

| Situation | Default | With `--strict` |
|---|---|---|
| Path does not exist | `⚠️` warning on stderr; entry skipped | `⛔` error on stderr; exit 1 |
| Not a regular file (directory, socket, FIFO…) | same | same |
| Permission denied / unreadable | same | same |

Skipped entries appear only in the stderr summary; they never produce stdout output, so the LLM never sees a phantom file.

| Code | Meaning |
|------|---------|
| 0 | Success — includes skipped entries (unless `--strict`) and an empty list. |
| 1 | Usage error (unknown flag), or a fatal entry under `--strict`. |

## Pipeline Role

`cx` is a **Context Provider** like `lx` and `bx`; the difference is the input: `bx` injects command output, `lx` injects argument-named files, and `cx` injects whatever files a *previous command in the pipe* discovered. The standard automation pattern:

```bash
# 1. discover -> 2. ingest -> 3. query -> 4. plain-text result
rg --files -g '*.go' | cx | ask "Summarize the architecture of this module." | answer
```

## Examples

**1. Discovery-driven ingestion**
```bash
$ find src -name '*.sh' | cx | help "Which of these scripts don't set -euo pipefail?"
```

**2. Review only what changed**
```bash
$ git diff --name-only HEAD~1 | cx | ask "Review these changes for style and bug risk."
```

**3. CI: fail on stale lists**
A manifest saved by an earlier build step; if a listed file was deleted since, default mode would silently shrink the context — `--strict` makes that a hard failure:
```bash
$ cx --strict < changed_files.txt | ask "Generate release notes for exactly these files." | answer > notes.md
```

**4. Filenames with hostile characters**
```bash
$ find . -print0 | cx -0 | ask "Map the repository layout."
```

**5. Merging overlapping lists without repetition**
```bash
$ { git ls-files '*.py'; grep -rl --include='*.py' TODO src/; } | cx -u | ask "List every TODO with file and line."
```

**6. Line numbers and a custom header**
```bash
$ rg --files | cx -n --before='### {filename} ({language})\n```{language}' | help "Propose a documentation index"
```

**7. Mixing argument and stream ingestion**
Because `lx` and `cx` emit the same block format, their outputs concatenate seamlessly:
```bash
$ { lx README.md; git ls-files 'src/*.py' | cx; } | help "Check the docs against the code"
```

## Gotchas

| Situation | What happens / what to do |
|---|---|
| Piping *file content* instead of a list (`cat main.py \| cx`) | Every content line is treated as a filename — a wall of `⚠️` warnings. `cx` consumes a **list**, not content; for content use `lx main.py` or plain `cat`. |
| Filenames starting with `#` | Skipped as comments in newline mode; use `-0`. |
| Producer dies mid-stream under `set -o pipefail` | `cx` exits 0 for the entries it did see; it cannot know the list was truncated. Guard critical flows by generating the complete list first, then `--strict`. |
| Using `cx` in scripts | As with all Hallux commands, `hx-bootstrap.sh` must be sourced (and `hx core` run) first. |
