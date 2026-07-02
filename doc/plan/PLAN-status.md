### Status Report against PLAN.md

**Overall Status: Partially Implemented**

The framework has successfully implemented the core pipeline architecture (Conversation, Tool, and Hybrid modes) but has significant pending items regarding advanced features and robust error handling.

---

#### **1. Pipeline Continuity & Robustness**
*   **[x] Input Validation:** `ask.sh` now validates if stdin is a JSON array (checks for `[`), preventing silent conversation resets.
*   **[ ] Error Propagation:** **PENDING.** While functions check exit codes, it does not yet implement `set -o pipefail` or `${PIPESTATUS}` logic to ensure a failure in the middle of a long pipe aborts the entire chain.
*   **[ ] Integration Testing:** **PENDING.** No `test/pipeline_test.sh` is present.
*   **[x] Documentation:** The pipeline patterns are documented in `README.md`.

#### **1a. Pipeline Architecture (Tee & Tools)**
*   **[x] `answer --tee` / `-t`:** Fully implemented in `answer.sh`. It correctly routes text to `stderr` and JSON to `stdout`.
*   **[x] `tools.sh` Wrapper:** Implemented as a pipeline wrapper for `toolex`, which itself needs considerable work.
*   **[x] Alias/Function Updates:** `functions.sh` provides updated wrappers for `ask`, `answer`, `bx`, `unfence`, and `tools`.

#### **2. `--file` Flag**
*   **[ ] Status: NOT STARTED.** There is no implementation of a `-f` or `--file` flag in `ask.sh`. Users must still use the `bx cat file | ask -i` workaround.

#### **3. Pipeline Idempotency (Caching)**
*   **[ ] Status: NOT STARTED.** No implementation for `--save`, `--resume`, or conversation caching exists.

#### **4. Modern LLM Techniques**
*   **4a. Tool/Function Calling:** **PARTIALLY IMPLEMENTED.** The `tools` wrapper is available, but the logic to automatically dispatch `finish_reason == "tool_calls"` and re-submit results (single-step tool use) is not yet integrated into the core `ask.sh`.
*   **4b. Structured Output:** **NOT STARTED.** No `--json` or `--schema` flags.
*   **4c. System Prompt Support:** **IMPLEMENTED.** `ask.sh` supports `--use-system-message` to prepend a system role message from the environment.
*   **4d. Streaming:** **NOT STARTED.** `ask.sh` uses synchronous `curl`.
*   **4e. Model Selection:** **PARTIALLY IMPLEMENTED.** The model is hard-coded as `gpt-3.5-turbo` in `ask.sh`; no `--model` flag exists yet.
*   **4f. Multimodal:** **NOT STARTED.**

#### **5. Housekeeping**
*   **[x] `bx` fix:** Exit code handling for the wrapped command was addressed in `bx.sh`.
*   **[ ] Makefile/Linting:** **NOT STARTED.**

---

### **Summary Table**

| Feature | Status | Notes |
| :--- | :--- | :--- |
| **Conversation Mode** | ✅ Complete | Uses magic header and JSON history. |
| **Tool/Extraction Mode** | ✅ Complete | `answer` transforms JSON to text. |
| **Hybrid Mode (`-t`)** | ✅ Complete | Text to `stderr`, JSON to `stdout`. |
| **System Messages** | ✅ Complete | Implemented via `--use-system-message`. |
| **File Attachment** | ❌ Missing | Requires manual piping/`ask -i`. |
| **Caching/Idempotency**| ❌ Missing | No `--save` or `--resume` functionality. |
| **Model Selection** | ⚠️ Partial | Hard-coded to `gpt-3.5-turbo`. |
| **Streaming** | ❌ Missing | No support for token streaming. |
