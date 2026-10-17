# unfile

Extract the fenced code block belonging to a named file from a markdown archive on **stdin** → **stdout**.

A pure filter. No TTY, no prompts, no side-effects. Safe for piping.

## Usage

```bash
unfile <filename>
```

| Arg | Required | Description |
|-----|----------|-------------|
| `<filename>` | yes | Heading to match, e.g. `bin/unfile.sh` |

## How matching works

`unfile` scans for a level-1 heading whose text equals `<filename>` after normalisation:

```
# file bin/unfile.sh   →   bin/unfile.sh
# bin/unfile.sh        →   bin/unfile.sh
```

Once the heading is found, the **next** fenced code block (``` … ```) is captured and its inner lines are printed. The fence delimiter and info-string are discarded.

Only the **first** match is emitted; scanning stops after extraction.

## Examples

```bash
# Round-trip through lx
$ lx a.sh b.sh c.sh | unfile b.sh
bar

# From a saved archive
$ cat archive.md | unfile bin/unfile.sh
#!/bin/bash
# Extracts specified filename from markdown archive …
```

## Exit codes

| Code | Meaning |
|------|---------|
| 0 | File found and written to stdout (or no match → empty stdout) |
| 1 | Incorrect number of arguments |

## See also

* [`unfence`](unfence.md) – extract a code block by language or index (interactive)
* [`lx`](lx.md) – produce the markdown archive that `unfile` consumes
