# gx

`gx` emits two versions of a file for comparison: the version from a Git revision and the current working-tree version.

## Synopsis

    gx [REV] FILE

`REV` defaults to `HEAD`.

Both versions are written to stdout as file inputs suitable for commands such as `dreck`.

## Examples

Compare the current file with `HEAD`:

    gx start-llama-server.sh | dreck

Compare the current file with an older revision:

    gx HEAD~3 start-llama-server.sh | dreck
