# Hallux, Elephant, and Goldfish

## What Is the Elephant-Goldfish Model?

The **Elephant-Goldfish Model (EGM)**—introduced by Dave Rensin in the Google Research paper *[Elephants, Goldfish and the New Golden Age of Software Engineering](https://research.google)* and open-sourced in the [google/elephant-goldfish-model](https://github.com) repository (see also the [Google Open Source Blog announcement](https://googleblog.com))—is a two-stage pattern for keeping AI-assisted coding accurate:

1. **The Elephant (Write with Memory):** You work in a context-rich, multi-turn session to explore trade-offs and produce a complete Markdown design specification before writing any code. Because the Elephant remembers every decision and debate, it is prone to blind spots and unstated assumptions.
2. **The Goldfish (Review without Memory):** You hand that Markdown spec—and only the relevant source files—to a brand-new, zero-memory session. Because the Goldfish has no history of the brainstorming chat, it immediately exposes missing details, ambiguities, and contradictions that would otherwise derail code generation.
3. **The Developer (Decide & Approve):** You review the Goldfish's findings, update the spec until it stands on its own, and only then generate implementation code.

---

## Why `answer` Fits Naturally

Most chat interfaces and agent harnesses work hard to preserve session state, requiring special subagent plugins to simulate a blank slate. In **[`answer`](../README.md)**, the Posix pipe gives you both roles natively:

* **Chained commands (`ask | ask`)** pass the JSON conversation history forward, acting as the **Elephant**.
* **A new command (`lx ... | ask`)** starts with zero conversation history by default, acting as the **Goldfish**.
* **Writing to disk (`| answer > doc/spec.md`)** creates a clean boundary between drafting and review.

---

## Step-by-Step Workflow

### 1. Grow the Elephant (Draft the Spec)

Use `lx` (and `bx` if you want live command output) to load project context from [`HALLUX.md`](../HALLUX.md) and [`LESSONS.md`](../LESSONS.md), then chain `ask` turns to debate options and draft a self-contained spec. Terminate with `| answer` so plain Markdown is written to disk rather than conversation JSON:

```bash
lx HALLUX.md LESSONS.md bin/target.sh \
  | ask "Let's design <feature>. List open questions and trade-offs first—do not write code yet." \
  | ask "Use approach B. Write a complete, self-contained Markdown design spec with acceptance criteria and edge cases. Output only Markdown." \
  | answer > doc/spec.md
```

*(Optional)* Save the design context to Git notes without cluttering your commit log:

```bash
hx provenance add describe
```

---

### 2. Test Against the Goldfish (Cold Review)

Start a **separate, unchained** `ask` command. Because nothing is piped from the Elephant session, the model sees only `doc/spec.md` and the source files you explicitly feed it:

```bash
lx doc/spec.md HALLUX.md bin/target.sh \
  | ask "You are seeing this spec for the first time with no prior context. Audit doc/spec.md against the source code and project rules. List:
1. Unstated assumptions
2. Ambiguities that would force an implementer to guess
3. Contradictions with existing code or HALLUX.md
4. Missing edge cases or failure modes"
```

---

### 3. Resolve & Re-Check

Update `doc/spec.md` to fix any gaps the Goldfish catches—either by editing the file directly or feeding the critique back into a drafting pass—and re-run Step 2 until the spec holds up on its own.

---

### 4. Implement from the Approved Spec

Once `doc/spec.md` passes Goldfish review, generate code from a clean context using only the approved spec and target files, then inspect before running with `unfence`:

```bash
lx doc/spec.md HALLUX.md bin/target.sh \
  | ask "Implement doc/spec.md. Follow all rules in HALLUX.md." \
  | unfence bash
```

---

## Practical Tips

* **Never pipe Elephant directly into Goldfish:** Running `ask "write spec" | ask "review spec"` carries the full conversation history across the pipe. Always write the spec to a file (`| answer > doc/spec.md`) and start a fresh pipeline for the review.
* **Fix the spec, not the chat:** If the Goldfish spots a missing detail, record the answer in `doc/spec.md` rather than explaining it in a follow-up prompt so the file remains the single source of truth.
