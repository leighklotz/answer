# dreck

**`dreck`** is a comparison utility for auditing LLM rewrites. It performs a rigorous side-by-side analysis of two versions of a file — typically an original source and a rewritten version produced by an LLM — and reports on conversational boilerplate, lazy elisions, and substantive quality changes.

The command ingests the two inputs with `lx` and runs them through `ask` with a fixed comparison system prompt. It is intended for detecting "LLM dreck": unnecessary conversational intro/outro or boilerplate in the second file, and for ensuring no critical content from the first file was omitted, summarized away, or truncated.

## Synopsis

```bash
dreck [FILE1 FILE2] [-- [EXTRA_PROMPT...]]
```

If `FILE1` and `FILE2` are supplied, they are ingested via `lx` and piped to `ask`. 
If no files are supplied (e.g., when reading from a pipeline), it compares two entities arriving on stdin — e.g., the output of an existing command or any other stream — using the same comparison logic.

The `--` separator is used to pass additional user prompt words that are appended to the built-in comparison prompt via `ask`.

## Description

`dreck` sources `env.sh`, `logging.sh` and `functions.sh` and then builds a conversation with `ask`. 

If two positional arguments are provided, it first performs an equality check using `cmp`; if the files are identical, it reports this fact via `ask` and exits immediately without triggering an LLM inference. If they differ, it proceeds to comparison.

The fixed system prompt used for every comparison is:

> Perform a rigorous comparison between these two files. 0) if the file is JSON, empty, binary data, etc. report that fact and stop immediately. 1) Detect any 'LLM dreck' in the second file (unnecessary conversational intro/outro or boilerplate). 2) Check for lazy elisions—ensure no critical content from the first file was omitted, summarized away, or truncated in the second version. 3) Conclude if the changes represent a substantive improvement in quality and completeness.

When two positional arguments are present:

```bash
lx "$1" "$2" | ask "$@" "${PROMPT}" "${USER_PROMPT}"
```

When no files are given the pipeline is:

```bash
ask "$@" "${PROMPT}"
```

`USER_PROMPT` is currently unpopulated in the implementation; the TODO in the script describes the intended behaviour of appending words after `--` to the base prompt as a user extension.

## Input Modes

| Condition | Behaviour |
|-----------|-----------|
| `dreck FILE1 FILE2` | Ingests both files with `lx` and compares them. |
| `dreck FILE1 FILE2 -- EXTRA...` | Same as above, with additional prompt words forwarded to `ask`. |
| `dreck` with piped input | Compares two entities arriving on stdin (e.g., a single block of text from an LLM or the output of a command) and passes them through `ask`. |
| `dreck -- EXTRA...` with piped input | Same as above with an extra user prompt extension passed to `ask`. |

## Examples

**Compare two files**

```bash
$ dreck original.md rewritten.md
```

**Compare two files with an additional instruction**

```bash
$ dreck original.md rewritten.md -- "Focus on factual accuracy and citation preservation"
```

**Compare pipeline inputs**

```bash
# Comparing a single stream of text/diffs against the comparison prompt
$ git diff -U10 file1.md file2.md | dreck -- "Highlight any missing code blocks"
```

## Comparing Git Versions

Use `gx` to compare the current working-tree version of a file with the version in `HEAD`:

    gx start-llama-server.sh | dreck
