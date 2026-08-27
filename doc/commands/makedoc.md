# makedoc

**`makedoc`** is a documentation orchestration utility that uses the Answer toolchain LLM pipeline to generate or update Markdown usage documents for commands. It builds a context bundle from source scripts, `README.md`, tests and existing docs, then runs `lx ... | ask "..." | answer | _strip_markdown_fence` to produce `doc/commands/<cmd>.md`.

It is not a parser. Documentation is produced by prompting the model with the command implementation and project context.

## Synopsis

```bash
makedoc [COMMANDS...]
```

If no COMMANDS are given, a default set is processed. If one or more COMMANDS are supplied, only those commands are processed.

## Description

`makedoc` iterates over the target commands and for each command:

1. Determines the source file:
   * `${SCRIPT_DIR}/${cmd}.sh` if it exists
   * otherwise `${SCRIPT_DIR}/commands/${cmd}.sh`
   * If neither exists, the script exits with an error.
2. Builds a context array:
   * Files from `$MAKEDOC_PREREADING` if set
   * The source file determined above
   * `README.md tests/story-test.sh doc/commands/*.md`
3. Ingests the context with `lx`
4. Prompts the model via `ask`:
   * If `doc/commands/${cmd}.md` exists:  
     `Check and update the usage document \`doc/commands/${cmd}.md\` for the $cmd command implemented in $src. Output the new usage file, not delta instructions.`
     Output is written to `doc/commands/${cmd}.md.new`
   * If the doc does not exist:  
     `Create the usage document \`doc/commands/${cmd}.md\` for the $cmd command for $src`
     Output is written to `doc/commands/${cmd}.md`
5. Fails if the destination file is empty.

The script creates `doc` if needed, uses `shopt -s nullglob`, and skips a command if `doc/commands/${cmd}.md.new` already exists.

Diagnostic information such as `CMDS=...` and `MAKEDOC_PREREADING=...` is printed to stdout; per-command progress is written to stderr.

## Environment Variables

| Variable | Description |
|----------|-------------|
| `MAKEDOC_PREREADING` | Optional space-separated list of additional files to prepend to the context for every command. |

## Default Commands

When invoked with no arguments the following commands are processed:

```
answer ask bx dreck help-commit help hx lx makedoc systype tools unfence
```

## Examples

**Process the default set**
```bash
$ makedoc
CMDS=answer ask bx dreck help-commit help hx lx makedoc systype tools unfence
MAKEDOC_PREREADING=
cmd=answer->.../bin/answer.sh
...
```

**Process a specific command**
```bash
$ makedoc answer ask
```

**Add extra pre-reading context**
```bash
$ export MAKEDOC_PREREADING="doc/plan/overview.md"
$ makedoc help
```

**Regenerate a single doc without overwriting the original**
If `doc/commands/help.md` exists, the new output is written to `doc/commands/help.md.new`. Remove or rename the `.new` file to replace the published doc after review.
```bash
$ makedoc help
