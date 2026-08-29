### Controlling the Black Box: A Language Model Interface for the Command Line

If you are comfortable with a bash prompt, you are probably skeptical of tools that try to automate away your environment. The LLM landscape has commoditized: models are bigger, context windows are wider, and every vendor ships an agent with its own REPL, browser, and walled-garden state. Those abstractions still introduce friction, hidden network calls, and opaque data loops.

You do not need a tool that attempts to write your software for you; you want something that respects your existing workflow, gives you explicit control over the data loop, and behaves like a predictable utility. That is still the premise of **Answer**.

The **Answer** toolchain is built for developers who prefer controlling the black box from a standard prompt. It does not replace your local environment or try to act as an all-knowing agent. Instead, it treats language models as standard command-line filters inside a bash environment (Linux and macOS, Bash 4+), with first-class support for native tool calling and provenance.

You can still use a simple one-shot:
```bash
help "what is the difference between '-t 0' and '-t 1' in bash tests?"
```

Or pipe text in and out, keeping the model securely bound inside standard inputs and outputs alongside `grep`, `awk`, and `sed`. Crucially, you can pipe between tools in the Answer toolchain itself. Inference responses are cached under `.hallux/cache` (falling back to `~/.config/hallux/cache/` when no workspace is in play) — cache hits show 🎯, misses show ✨, and tool calls are never cached.

---

## Decoupling State from Walled Gardens

The problem with conventional terminal wrappers is that they force users into custom REPLs or rigid, isolated interfaces. `answer` bypasses this by storing and passing conversation state directly through standard pipes with a magic header:

```
Content-Type: application/x-llm-history+json
```

Interactive terminal sessions automatically extract and display plain text via `answer`, while machine-to-machine pipelines preserve the structured conversation for further processing.

Because this state lives entirely inside the pipeline, you inherit the flexibility of the shell itself:

* **Forking conversations** using shell history rather than GUI window controls.
* **Injecting context** using standard redirection and pipelines.
* **Editing previous prompts** using existing shell tooling.

If you want to explore an alternate solution, you don't click a branch button in a UI; you use your shell history. Hit the up-arrow, tweak a prompt parameter in the middle of your pipe, and run it again. The original context remains entirely untouched in your history.

The conversation becomes just another data stream. With ad-hoc ingestion, you control exactly what context the model sees. Need it to evaluate a compiler error or a local file? Just feed it through standard input:
```bash
help "What am I missing here?" < build.log
```
For pasting text chunks by hand, `ask -i` reads multi-line input terminated with Ctrl-D.

Provenance is now a first-class concern. `hx provenance add` bookmarks significant terminal interactions as Git notes under `provenance/hallux`, giving you an auditable trail of command + response without polluting your git log. Nothing is recorded unless you call `hx provenance` directly, and the feature is still a work in progress.

---

## The Minimalist Toolchain, 2026

The system is built from small, focused components:

* **`ask`** constructs conversation state from prompts and `stdin`.
* **`help`** is a specialized `ask` wrapper for quick Python/Bash questions.
* **`answer`** extracts plain text from structured conversation history when you need to terminate a pipeline or redirect output. Usually auto-invoked at end of CLI, but you need to call it if you redirect output: Always use `| answer > file`, never `> file` directly.
* **`unfence`** extracts executable code from markdown fences and inserts an interactive confirmation step before execution.
* **`lx`** streams files into conversations as markdown blocks.
* **`bx`** captures command output for later inference, with the command itself documented in the prompt.
* **`tools`** routes the JSON conversation through `toolex.py` to resolve native model tool calls while preserving pipeline semantics and permission caps; at a terminal it passes the final response through `answer` for you.
* **`hx`** manages workspace discovery `.hallux`, cache operations, model selection, and provenance. It can replay the last response (`hx what`, 💬) or reasoning trace (`hx why`, 🧠) from your most recent inference.
* **`systype`** provides system profiling metadata so reasoning is grounded in your actual hardware.

Status emoji are now part of normal output:

| Icon | Meaning |
| :--- | :--- |
| ✨ | Inference, cache miss |
| 🎯 | Inference, cache hit |
| 💬 | piped content input |
| 😺 | `bx` shell input |
| 📥 | `lx` file input |

---

## The Interface in Practice

Because the toolchain behaves like a standard filter, you can chain multiple turns of a technical conversation or audit your own local terminal history in a single line of shell code.

### Example 1: Multi-Turn Pipeline with Observation
Imagine you want to draft a logic block, modify its parameters, translate it across languages, and run it safely:

```bash
ask write fib in bash \
    | ask "call it with 20" \
    | ask -t translate to python and output code fence \
    | unfence python \
    | python
```
`-t/--tee` shows human-readable text on stderr while keeping the JSON history on stdout.

### Example 2: Documenting an Interactive Session
```bash
history | tail -30 \
    | help "Summarize my recent actions as a concise markdown guide, skipping failed attempts."
```

Or with full command evolution:
```bash
fc -l -40 | help "I've been resolving a merge conflict for the last 15 minutes. Based on these commands, clarify where I derailed and provide cleanup steps."
```

### Example 3: Safe Tool Calling
With `tools` you can expose a permissioned tool set to the model:
```bash
ask "Find unused imports" | tools 'file:read=src/*.py'
```
Tool specs are `module[:capability][=pattern]`, or multiple capabilities in one spec (`file:read=a.py:write=a.py.bak`): `tools git:read` exposes only the read-only git tools, `tools 'file:read=*.py'` restricts file access to matching globs, and a bare module name grants the whole module. Quote specs containing globs so your shell doesn't expand them first. Pass multiple specs by repeating `--tools` (e.g. `tools --tools git --tools 'file:read=*.py'`), since the flag no longer accepts a space-separated list. Host bash tools (`bash`) are separated from sandboxed Podman tools (`podbash`), which run with no network and a read-only workspace mount unless write capabilities are granted, and capabilities are declared per function. Agentic runs are capped at 30 tool-call iterations.

The `toolex` package also ships `help-commit`, a ready-made pipeline — `ask … | tools git | unfence | bash` — that inspects your working tree and drafts conventional commits behind `unfence`'s confirmation gate.

---

## Designed for Process Control

The toolchain intentionally avoids hidden state, background daemons, and proprietary interaction models. It integrates effortlessly into emacs via `shell-command-on-region`, scripts, cron jobs, and existing development workflows.

`hx enable` adds a `🐣` prompt marker and activates the `.hallux` workspace discovery. The cache lives under `.hallux/cache/` or falls back to `~/.config/hallux/cache/`. The API endpoint and key are configured in `bin/commands/env.sh`; `hx model` manages model configuration, and `hx set-model` switches the active model for the current session.

The **Answer** toolchain doesn't try to manage your project or dictate your workflow. It treats language models as predictable filters, giving developers a clean, scriptable way to manipulate code streams.

The goal is not to replace the command line. The goal is to make language models behave like another well-behaved command-line utility in 2026 — local, auditable, and under your control.

---

Check out **answer** at https://github.com/leighklotz/answer and see the examples. For tool calling details and sandboxing patterns see blog-post-2, and for provenance workflows see blog-post-3.
