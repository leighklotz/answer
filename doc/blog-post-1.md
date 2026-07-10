### Controlling the Black Box: A Language Model Interface for the Command Line

If you are comfortable with a bash prompt, you are probably skeptical of tools that try to automate away your environment. Solutions that inject large, opaque abstractions into your setup often introduce more friction than they resolve. You do not need a tool that attempts to write your software for you; you want something that respects your existing workflow, gives you control over the data loop, and behaves like a predictable utility.

The **Answer** toolchain is built for developers who prefer controlling the black box from a standard prompt. It does not replace your local environment or try to act as an all-knowing agent. Instead, it treats language models as standard command-line filters operating inside a POSIX shell environment.

You can use a simple command `help` to get quick one-shot answers to your programming questions—for example: 
`help "what is the difference between '-t 0' and '-t 1' in bash tests?"`

Or, you pipe text into it, and you pipe text out of it, keeping the model securely bound inside standard inputs and outputs alongside tools like `grep`, `awk`, and `sed`. Crucially, you can pipe between tools in the **Answer** toolchain itself. When you extend a pipeline, unchanged earlier inference stages are served from a cache, while new stages are inferred normally. This makes iterative editing fast and repeatable.

---

## Decoupling State from Walled Gardens

The problem with conventional terminal wrappers is that they often force users into custom REPLs or rigid, isolated interfaces. The `answer` package bypasses this by storing and passing conversation state directly through standard pipes.

When these scripts are chained together, they pass a structured JSON conversation history downstream. Interactive terminal sessions automatically extract and display plain text, while machine-to-machine pipelines preserve the structured conversation for further processing. 

Because this state lives entirely inside the pipeline, you inherit the flexibility of the shell itself:

* **Forking conversations** using shell history rather than GUI window controls.
* **Injecting context** using standard redirection and pipelines.
* **Editing previous prompts** using existing shell tooling.

If you want to explore an alternate solution, you don't click a branch button in a UI; you use your shell history. Hit the up-arrow, tweak a prompt parameter in the middle of your pipe, and run it again. The original context remains entirely untouched in your history. 

The conversation becomes just another data stream. With ad-hoc ingestion, you control exactly what context the model sees. Need it to evaluate a compiler error or a local file? Just feed it through standard input:
```bash
help "What am I missing here?" < build.log
```

---

## The Minimalist Toolchain

The system is built from small, focused components:

* **`ask` / `help`** constructs conversation state from prompts and `stdin`.
* **`answer`** extracts plain text from structured conversation history when you need to terminate a pipeline or redirect output.
* **`unfence`** extracts executable code from markdown fences and inserts a confirmation step before execution.
* **`lx`** streams files into conversations as markdown blocks.
* **`bx`** captures command output for later inference.
* **`tools`** resolves model tool calls while preserving pipeline semantics.
* **`hx`** manages shell integration and cache operations.

---

## The Interface in Practice

Because the toolchain behaves like a standard filter, you can chain multiple turns of a technical conversation or audit your own local terminal history in a single line of shell code. A multi-turn conversation remains an ordinary shell pipeline.

### Example 1: Multi-Turn Pipeline Translation
Imagine you want to draft a logic block, modify its parameters, translate it across languages, and run it safely:
```bash
help write fib in bash \
    | help call it with 20 \
    | help translate to python \
    | unfence python \
    | python
```

### Example 2: Documenting an Interactive Session
One of the best inputs for a language model is your own local terminal trail. If you just spent 15 minutes troubleshooting a complex Git rebase or fine-tuning environment variables, that history contains your exact context. You can use standard shell mechanics like `fc` (Fix Command) to capture that trail and pass it downstream.

Your command history becomes useful context:
```bash
history | tail -30 \
    | help "Summarize my recent actions as a concise markdown guide."
```

Or, for more complex debugging where you need the model to see exactly how your commands evolved over time:
```bash
fc -l -40 | help "I've been resolving a merge conflict for the last 15 minutes. Based on these commands, clarify where I derailed and provide cleanup steps."
```

---

## Designed for Process Control

The toolchain intentionally avoids hidden state, background daemons, and proprietary interaction models. It is designed to be editor-friendly; because the architecture relies entirely on standard input/output rather than heavy terminal UIs, it integrates effortlessly into text editors (like Emacs via `shell-command-on-region`), scripts, cron jobs, and existing development workflows.

The **Answer** toolchain doesn't try to manage your project or dictate your workflow. It treats language models as predictable filters, giving developers a clean, scriptable way to manipulate code streams. 

The goal is not to replace the command line. The goal is to make language models behave like another well-behaved command-line utility.

---

Check out **answer** at [https://www.github.com/leighklotz/answer](https://www.github.com/leighklotz/answer) and see the [examples](https://github.com/leighklotz/answer/blob/main/doc/examples.md).

