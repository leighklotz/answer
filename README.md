# Answer: 🤖 A Shell-Based Code Generation & Execution Agent Framework

**Answer** is a command-line LLM-based agent framework that uses Posix pipes to compose and execute nonce agentic pipelines. It provides a conversational, shell-focused workflow for rapid prototyping, experimentation, and analysis.

## The State-Driven Pipeline Model

To allow seamless transitions between "thinking" (conversation) and "doing" (tooling), **Answer** tracks conversation states using an internal `infer()` engine primitive. This eliminates messy data format-juggling inside your shell pipes.

### 1. Conversation Mode (`ask | ask`)
* **Goal:** Build a continuous conversation where each command appends to the running history.
* **How it works:** `ask` passes heavy JSON arrays containing full history through pipes via a magic header. If a trailing `ask` detects a pending user prompt from the previous step, it automatically calls `infer()` to resolve it before adding the next turn.
* **Pattern:** `ask "Q1" | ask "Follow up Q2"`

### 2. Tool/Extraction Mode (`ask | answer | tool`)
* **Goal:** Take the text result of an LLM and pass it straight to a shell command (like `python`, `bash`, or `pipetest`).
* **How it works:** The `answer` command acts as your permanent pipeline "Cut-Point." It auto-resolves any pending queries using `infer()`, drops the outer JSON history envelopes entirely, and outputs **Pristine Plain Text** markdown strings. This acts as a natural gatekeeper for standard shell utilities.
* **Pattern:** `bx cat file.txt | ask "Refactor this code" | answer | pipetest OK | unfence | bash`

### 3. Hybrid/Observation Mode (`ask -t | ask`)
* **Goal:** See what the LLM generated in your terminal *while also* preserving the conversation JSON history for the next command.
* **How it works:** The `--tee` (or `-t`) flag on `ask` resolves the current turn, prints the human-readable text out to `stderr` for you to look at, but sends the full conversation JSON history down `stdout`.
* **Pattern:** `ask -t "Generate base bash script" | ask "Add error handling to it"`

---

## Core Components

* **`infer()`**: *The Engine Primitive.* An internal shared helper function. It checks if a conversation history array ends with a `user` query. If it does, it calculates your byte-accurate local cache keys, logs your horizontal tracking status emojis (`🎯` or `💭`) to `stderr`, runs the inference call, appends the `assistant` object, and spits the updated full JSON history out to `stdout`.
* **`ask`**: *The State Builder.* Manages conversational turn-taking. It processes inputs, hooks into `infer()` to catch up on un-resolved context strings, appends your new query block, and pipes directly to `answer` if it detects it is at the end of a line (terminal window).
* **`answer`**: *The Text Extractor.* The terminal endpoint of the execution tree. It takes your conversation data, resolves it, pushes a clean newline to `stderr` to wrap up your emoji tracker row, and delivers raw text tokens to `stdout`.
* **`bx`**: Executes a target command and wraps its raw console output inside a clean markdown code fence.
* **`unfence`**: Strips triple-backtick (```) markdown fences from an incoming text stream to prepare code for execution.
* **`pipetest`**: Captures clean text from `stdin`, runs it through a pager visualizer on `stderr`, and safely pauses to ask you `Y/N` via your keyboard before feeding it forward.
* **`tools`**: Pipeline wrapper around `toolex.py`. Reads a JSON conversation array, resolves native LLM tool calls via toolex, and writes the updated conversation array to stdout.
* **`story.txt`**: A comprehensive file containing example usage scenarios, prompts, and expected outputs to help you get started.

---
## Testing

Automated verification of pipeline outputs is handled by `story-test.sh`. This script simulates expected outputs for common use cases (Fibonacci, Hello World, Math, Sorting) to ensure the `ask`, `answer`, and execution chain behave as documented.

Run tests using:
~~~bash
chmod +x tests/story-test.sh
./tests/story-test.sh
~~~

## Examples

**Chaining questions (Conversation Mode):**
```bash
ask "What is 20+30?" | ask "Convert that result to octal"
# Output: 
# 💭💭
# 50 in decimal is 62 in octal.
```

**Running code (Tooling Mode):**
```bash
ask "Write a python script to list files" | answer | unfence | python
```

### Test Case: Context Preservation
Understanding how context flows through different modes is crucial for effective prompting:

**1. Successful Context Chain (`ask | ask`):** The history is passed via JSON automatically.
```bash
$ ask say boo | ask why did you say that
Because you asked me to! You said "say boo," so I followed your instruction. 👻
```

**2. Intended Interface Cut (`ask | answer`):** Using `answer` drops the JSON history to raw text to communicate with your terminal window or standard shell utilities.
```bash
$ ask say boo | answer
Boo! 
```

---

## Workspace Cache Architecture

Your tools automatically crawl upwards from your current working directory to find a `.hallux` folder to claim as a project workspace and initialize a `cache/` directory inside it. If you run your tools outside an active project repository layout, they safely fall back to `~/.config/hallux/cache/` to keep your system clean.

```text
.hallux/cache/
└── _home_klotz_wip_models_Qwen3.6-35B...:5d97ec5e...:chatcmpl-iZss...json
```

---

## Pipeline Patterns

### Basic question and answer
```bash
ask "Write fib in Python" | answer
```

### Piping command output into a question (use `-i`)
```bash
dmesg | ask -i "Spot any SCSI issues" | answer
```

### Chained follow-up questions
Use `ask -t` mid-pipeline so the conversation JSON continues to flow on stdout while the human-readable reply appears on stderr:
```bash
dmesg | ask -i "Spot any SCSI issues" | ask -t "What can I do about the md0 device?" | answer
```

### Tool-call resolution with toolex
```bash
ask "Spot any SCSI issues with dmesg" | tools linux_tools | ask -t "What can I do about the md0 device?" | answer
```

---

## Prerequisites

Before you begin, ensure you have the following installed:
* **OpenAI API Key / Local Endpoint:** Required for accessing the inference backend.
* **`jq`:** A lightweight and flexible command-line JSON processor. Install via your package manager:
  * **Debian/Ubuntu:** `sudo apt-get install jq`
  * **macOS:** `brew install jq`
* **Python 3:** Needed for executing generated Python code.
* **Bash 4+:** The scripts are written specifically for Bash 4 or later.

---

## Setup

1. **Clone the Repository & Enable Paths:**
   ```bash
   git clone <repository_url>
   cd answer
   . enable.sh
   ```

2. **Set Environment Variables:**
   ```bash
   export VIA_API_CHAT_BASE="http://localhost:5000"
   export OPENAI_API_KEY="your-key-if-applicable"
   ```

---

## License

This project is licensed under the [MIT License](LICENSE).
