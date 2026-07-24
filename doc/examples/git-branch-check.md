# Git Branch & State Auditing

Automate the validation of your workspace by piping branch names, statuses, and diffs through the toolchain for instant compliance checks. Use these workflows to ensure naming conventions are met, detect divergence from remote branches, or summarize uncommitted work before pushing code.


````bash
    klotz@tensor:~/wip/llamafiles-temp🦶$ git branch
      llm-vibe
      llm_el_fixes
    * main
    klotz@tensor:~/wip/llamafiles-temp🦶$ bx git branch | ask show oneline commits that happened to main after llm-vibe branched off | tools git
    🐚💬✨🚀git log --oneline llm-vibe..main
    ✨
    The commits that happened on `main` after `llm-vibe` branched off are:

    ```text
    345bed7 Ignore hallux directory
    c70a21d refactor: improve model name resolution in via/api/functions.sh
    9996260 Add log_trace function to via/logging.sh and implement tracing in via/api/functions.sh
    b475c1c Merge pull request #20 from leighklotz/llm-vibe
    ```
    klotz@tensor:~/wip/llamafiles-temp🦶$ git checkout llm--vibe
    error: pathspec 'llm--vibe' did not match any file(s) known to git
    klotz@tensor:~/wip/llamafiles-temp🦶$ bx git branch | ask show oneline commits that happened to main after llm-vibe branched off | tools git | ask are any of those commits making changes in the llm_el directory of the repo | tools git file bash
    🐚💬✨🚀git log --oneline llm-vibe..main
    ✨💬✨🚀git log --oneline llm-vibe..main -- llm_el
    ✨
    No, none of those commits made any changes in the `llm_el` directory.
    klotz@tensor:~/wip/llamafiles-temp🦶$ 
    ```

````
