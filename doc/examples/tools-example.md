# tools example

```
klotz@snapback:~/wip/answer🦶$ help summarize logs and diffs since main | tools git | help write a PR for the changes|ask avoid emoji
💬✨🤖 git log main..HEAD --oneline✨🤖 git diff main..HEAD✨💬✨✨
```

## Title: Refactor project structure to `bin/` directory and enhance CLI visual feedback

### Description
This PR reorganizes the repository by consolidating all core executable scripts and utility files into a centralized `bin/` directory. This change standardizes the project layout, simplifies path management, and improves distribution readiness. Additionally, this update introduces new status indicators in terminal output to improve command-line user experience through better visual feedback during execution.

### Changes

#### Project Restructuring
* **Consolidation:** Moved all primary scripts (`ask`, `answer`, `bx`, `lx`, etc.) and subcommands from the root/subdirectories into the `/bin` directory.
* **Path Updates:** Updated internal sourcing logic in `functions.sh` and various command files to correctly reference paths within the new `/bin` structure (e.g., updating `$PATH` entries and `source` calls).

#### UX & Visual Feedback
Introduced character-based status indicators for terminal output to provide immediate feedback during execution:
* **Piping/Forwarding:** Added a chat symbol in `ask` when messages are being forwarded via pipes.
* **Command Completion:** Added completion signals (mechanical arm and page symbols) in `bx` and `lx` upon successful operation completion.
* **API Interactions:** Enhanced visual confirmation for API calls in `functions.sh` using status characters to indicate processing state.

#### Test Suite Refactoring
* **Path Alignment:** Updated `tests/story-test.sh` to source dependencies from the new `/bin` directory structure instead of root relative paths.
* **Pipeline Optimization:** Streamlined several test command chains by removing redundant pipes where logic has been consolidated, improving testing reliability and speed.

#### Documentation
* Added a new documentation example: `doc/examples/tools-example.md`.

### Impacted Components
* All scripts previously located in the project root (now moved to `/bin`).
* Test suite configuration (`tests/story-test.sh`).
* Environment variable pathing logic for CLI tools.

### Checklist
- [x] Code structure follows the new organization standards.
- [x] Tests pass with updated directory paths and streamlined pipelines.
- [x] No breaking changes to core command logic; improvements are structural and UX-focused.
