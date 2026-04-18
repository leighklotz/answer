### Status Report against PLAN.md

**Overall Status: Partially Implemented**

The framework has successfully implemented the core pipeline architecture (Conversation, Tool, and Hybrid modes) but has significant pending items regarding advanced features and robust error handling.

---

#### **1. Pipeline Continuity & Robustness**
*   **[x] Input Validation:** `ask.sh` now validates if stdin is a JSON array (checks for `[`), preventing silent conversation resets.
*   **[ ] Error Propagation:** **PENDING.** While `functions.sh` checks exit codes for `ask.sh` and `answer.sh`, it does not yet implement `set -o pipefail` or `${PIPESTATUS}` logic to ensure a failure in the middle of a long pipe (e.g., `ask | ask | tool`) aborts the entire chain.
*   **[ ] Integration Testing:** **PENDING.** No `test/pipeline_test.sh` is present in the provided files.
*   **[x] Documentation:** The `README.md` has been updated with the new pipeline patterns.

#### **1a. Pipeline Architecture (Tee & Tools)**
*   **[x] `answer --tee` / `-t`:** Fully implemented in `answer.sh`. It correctly routes text to `stderr` and JSON to `stdout`.
*   **[x] `tools.sh` Wrapper:** Implemented (referenced in `functions.sh` and `README.md`).
*   **[x] Alias/Function Updates:** `functions.sh` provides updated `ask`, `answer`, `bx`, `unfence`, and `tools` wrappers.

#### **2. `--file` Flag**
*   **[ ] Status: NOT STARTED.** There is no implementation of a `-f` or `--file` flag in `ask.sh`. Users must still use the `bx cat file | ask -i` workaround.

#### **3. Pipeline Idempotency (Caching)**
*   **[ ] Status: NOT STARTED.** There is no implementation for `--save`, `--resume`, or conversation caching.

#### **4. Modern LLM Techniques**
*   **4a. Tool/Function Calling:** **PARTIALLY IMPLEMENTED.** The `tools` wrapper exists, but the logic to automatically dispatch `finish_reason == "tool_calls"` and re-submit results (single-step tool use) is not in `ask.sh`.
*   **4b. Structured Output:** **NOT STARTED.** No `--json` or `--schema` flags.
*   **4c. System Prompt Support:** **IMPLEMENTED.** `ask.sh` now supports `--use-system-message` and prepends the `SYSTEM_MESSAGE` env var to the JSON array.
*   **4d. Streaming:** **NOT STARTED.** `ask.sh` uses a standard synchronous `curl` call.
*   **4e. Model Selection:** **PARTIALLY IMPLEMENTED.** The model is hard-coded to `gpt-3.5-turbo` in `ask.sh`. There is no `--model` flag.
*   **4f. Multimodal:** **NOT STARTED.**

#### **5. Housekeeping**
*   **[x] `bx` fix:** The logic in `functions.sh` (via `bx`) and the description in `PLAN.md` suggest the exit code issue was addressed.
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
