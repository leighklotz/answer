# Test Cases for Answer Framework
These tests show the generally-expected form of output; there will be variation. Inputs are often mocked, and would likely be generated from other commands such as `bx` and `lx`, or from other ipiped Posix commands.

## 1. Basic Functionality
Standard execution of the `ask` command.

```bash
$ ask 2+3=
2 + 3 = 5
```

## 2. Tool/Extraction Mode
Verifies that `answer.sh` extracts the raw text from the LLM response when piped.

```bash
$ ask 2+3= | answer
2 + 3 = 5
```

## 3. Raw JSON Inspection
Verifies that the internal data structure is correctly formatted as JSON when piped to `cat`.

```bash
$ ask 2+3= | cat
[
  {
    "role": "user",
    "content": "2+3="
  },
  {
    "role": "assistant",
    "content": "5"
  }

]
```

## 4. JSON Parsing via Answer
Verifies that `answer.sh` can ingest raw JSON and extract the final content.

```bash
$ ask 2+3= | answer
5
```

## 5. Hybrid/Observation Mode (Tee)
Verifies that the `--tee` (`-t`) flag provides human-readable output to `stderr` while passing the structured JSON history through `stdout`.

```bash
$ ask 2+3= | answer -t
2 + 3 = 5
[
  {
    "role": "user",
    "content": "2+3="
  },
  {
    "role": "assistant",
    "content": "2 + 3 = 5"
  }
]
```

## 6. System Message & Peano Logic
Verifies functional correctness when a system message is applied.

```bash
$ export SYSTEM_MESSAGE="Act as a Peano arithmetic calculator."
$ ask 2+3=
2 + 3 = 5

$ ask --use-system-message 2+3=
To calculate $2 + 3$ using Peano axioms, we define natural numbers using the successor function $S(n)$, where $S(n)$ represents $n + 1$.

**Definitions:**
$0 = 0$
$1 = S(0)$
$2 = S(S(0))$
$3 = S(S(S(0)))$

**Addition Rule:**
1. $a + 0 = a$
2. $a + S(b) = S(a + b)$

**Step-by-step derivation:**
We want to calculate $2 + 3$, which is $S(S(0)) + S(S(S(0)))$:

1. $2 + S(S(S(0))) = S(2 + S(S(0)))$
2. $S(2 + S(S(0))) = S(S(2 + S(0)))$
3. $S(S(2 + S(0))) = S(S(S(2 + 0)))$
4. Apply the base case ($2 + 0 = 2$):
   $S(S(S(2)))$

**Expanding the successors:**
$S(2) = 3$
$S(3) = 4$
$S(4) = 5$

**Result:**
5
```

## 7. Conversation Mode (New: Pipeline Continuity)
Verifies that the `PIPELINE_MAGIC_HEADER` allows context to persist across multiple `ask` commands.

```bash
# First call establishes context
$ ask "My name is Peano"
Hello! I am ready to assist with Peano arithmetic.

# Second call inherits history via magic header
$ ask "My name is" | ask
My name is Peano.
```

## 8. Deep Pipeline Extraction (New: Tool Chaining)
Verifies that `answer.sh` successfully strips all headers and JSON when part of a multi-stage Unix pipe.

```bash
# Verifies that 'grep' receives only the text, not the JSON structure or magic header
$ ask 2+3= | answer | grep "5"
5
```

## 9. Protocol Integrity (New: Header Detection)
Verifies that `ask.sh` correctly identifies and reconstructs conversation history from a piped stream containing the magic header.

```bash
# Manually simulate the magic header and JSON payload
$ echo "Content-Type: application/x-llm-history+json" > dummy.json
$ echo '[{"role": "user", "content": "Previous context"}]' >> dummy.json
$ cat dummy.json | ask "What did I just say?"
You just said "Previous context".
```
## 10. Last Answer Retrieval (No Stdin)
Verifies that calling `answer` without piped input correctly retrieves the most recent interaction, if available.

```bash
$ ask "2+3="
2 + 3 = 5
$ answer
2 + 3 = 5
```

## 11. Unfencing Code
Verifies that `unfence` correctly strips triple backtick (```) delimiters from model output.

```bash
$ echo '```python\nprint("hello world")\n```' | unfence
print("hello world")
```

## 12. Piping Command Output
Verifies the `-i` flag allows piping existing shell output into an `ask` prompt.

```bash
$ echo 'EXT4-fs error (device sda1): ext4_find_entry:1234: inode #567890: comm process: reading directory lblock 0' | \
  ask -i "Analyze this error" | answer
The error indicates a hardware failure on the disk.
```
## 13. Safe Execution Preview
Verifies that `pipetest` provides a preview and requires user confirmation before executing code.

$ ask "write a single bash echo of (2+3)" | answer | pipetest Execute | unfence | bash
```bash
🦶echo $((2+3))
```
🦶 Execute: Y or N? y

5
$ 
