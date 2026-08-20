# systype

**`systype`** is a system information utility designed to provide basic software metadata as part of an `answer` pipeline. It emits a Markdown-formatted description of the host system that can be piped directly into `ask`, `help`, or `bx` for grounded LLM reasoning.

## Synopsis

```bash
systype
```

`systype` takes no options or arguments.

## Description

When executed, `systype` prints a self-documenting Markdown block suitable for ingestion by the Answer toolchain:

* A header `# Description of this system:`
* An opening Markdown code fence ```` ```bash ````
* The literal prompt `$ uname -a` followed by the live output of `uname -a`
* The literal prompt `$ cat /etc/os-release` followed by the output of `/etc/os-release` with lines matching `^[A-Z_]+_URL="http` removed via `egrep -v`
* A closing Markdown code fence ```` ``` ````

The output is intentionally formatted as a bash fenced block so that downstream tools such as `lx`, `help` and `ask` treat the system data as structured context rather than raw text.

## Output format

```markdown
# Description of this system:
```bash
$ uname -a
<uname -a output>
$ cat /etc/os-release
<filtered /etc/os-release output>
```
```

## Examples

**System context for a question**

```bash
$ systype | ask "how do I find which package owns /usr/bin/env"
```

**Combined hardware/software profiling**

```bash
$ systype | help "summarize my OS and kernel"
```

**Passing system info to a multi-turn pipeline**

```bash
$ systype | ask "what is my current distribution?" | ask "what is the default package manager for it?"
```
