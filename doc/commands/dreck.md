# dreck

**`dreck`** is the sanitation and cleanup utility designed to purge transient artifacts left behind by interrupted or complex LLM pipelines within the Answer framework. It acts as a "garbage collector" for your workspace, specifically targeting orphaned temporary directories and stale runtime files that may persist after an inference session is aborted (e.g., via `SIGINT`/`Ctrl+C`) or if a pipeline crashes before reaching its cleanup phase.

By cleaning up this "dreck," you ensure a pristine execution environment, preventing filesystem clutter in `/tmp/` or your local workspace and avoiding potential conflicts with subsequent high-concurrency automated runs.

## Synopsis

```bash
dreck [OPTIONS]
```

## Description

When the Answer framework executes complex multi-stage pipelines (especially those involving long-running inference calls), it creates a shared temporary workspace (`HALLUX_RUN_DIR`) to manage intermediate JSON states, request buffers, and local cache lookups. While the `_cleanup_run_dir` function handles standard exits, interrupted processes can leave behind "orphaned" directories in your system's temporary folder (e.g., `/tmp/hallux_run.*`).

**`dreck`** scans for these unowned or abandoned workspaces and removes them, ensuring that the machine stays clean regardless of how an LLM session is terminated. It can also be configured to perform a "deep clean" by wiping local cache entries along with transient runtime files.

## Options

| Flag | Long form | Description |
|------|-----------|-------------|
| `--cache` | | **Deep Clean:** In addition to cleaning orphaned temporary workspaces, this flag instructs the utility to also purge all entries in your local LLM interaction cache (`hx cache clear`). |
| `--force` | | **Silent Mode:** Skips interactive confirmation prompts. Use with caution: once invoked, files are deleted immediately without a safety gate. |

## Visual Feedback (`stderr`)

Like other utilities in the Answer toolchain, `dreck` provides real-time status updates via icons on **stderr**:
* 🧹 **Cleaning:** Currently identifying and removing orphaned temporary workspaces.
* 🗑️ **Purging Cache:** Wiping local JSON interaction history (when `--cache` is used).
* ✨ **Cleaned:** The environment has been successfully restored to a pristine state.
* 🚫 **Aborted:** No orphans were found, or the operation was cancelled by the user.

## Input Modes

| Mode | Behavior | Target |
|-----------|----------|-------------------|
| **Standard** | Interactive cleanup of orphaned `HALLUX_RUN_DIR` directories in `/tmp`. | Temporary session files only. |
| **Deep Clean (`--cache`)** | Removes temporary workspaces AND all cached LLM responses. | Temp dirs + `.hallux/cache/*.json`. |

## Examples

**1. Standard Cleanup (The "Light" Sweep)**
Remove orphaned workspace directories left over from interrupted pipelines or crashed sessions. This is safe and will prompt for confirmation before deletion.
```bash
$ dreck
🧹 Cleaning...
Are you sure you want to remove 3 orphaned workspaces? (/tmp/hallux_run.*)
(y/N): y
✨ Cleaned.
```

**2. Deep Workspace Reset (The "Heavy" Sweep)**
Completely wipe the environment: clear out all cached LLM conversations and delete any lingering temporary files. Use this if you suspect local cache corruption or want to free up disk space significantly.
```bash
$ dreck --cache
🧹 Cleaning... 🗑️ Purging Cache...
Are you sure you want to perform a deep clean? (y/N): y
✨ Cleaned.
```

**3. Automated Sanitation (CI/CD Pipeline)**
In an automated environment or CI script where manual confirmation is impossible, use `--force` to ensure the cleanup completes silently as part of your build process.
```bash
# Run tests and then immediately clean up any mess left by failed test runs
$ ./tests/story-test.sh && dreck --force
✨ Cleaned.
```
