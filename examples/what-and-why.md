````
klotz@core:~/wip/answer🦶$ help-commit
```bash
git add doc/blog-post-1.md && \
git commit -m "docs: update blog post to clarify help command and piping mechanism"
```
y/N? y
...
klotz@core:~/wip/answer🦶$ hx what
🧠
```bash
git add doc/blog-post-1.md && git commit -m "docs: update description of tool usage and piping behavior in blog post"
```
klotz@core:~/wip/answer🦶$ hx why
💭
    *   Working directory: `/home/klotz/wip/answer` (Git root is also here).
        *   Changes in `doc/blog-post-1.md`:
            *   Removed a sentence about piping text into it and getting code out of it as part of the same paragraph.
            *   Added: "You can use a simple command `help` to get quick one-shot answers to your Linux or other programming questions."
            *   Refined/separated the description of how it works (piping).
            *   Added information about being able to pipe between tools and using cached results for idempotency.

        *   The changes are within a single file: `doc/blog-post-1.md`.
        *   The content change is updating documentation regarding the usage of the tool (`help` command, piping mechanism details). It's an update to existing prose in a blog post draft.

        *   Type: `docs` (since it's a `.md` file and describes how the tool works).
        *   Subject line: `doc: clarify usage patterns for Answer toolchain` or similar. Let's go with something descriptive like `docs(blog-post): update description of command usage and piping`.

        *   The user wants "a code fence containing a corresponding `git commit` command, using one or more bash git commands as appropriate".
        *   I need to stage the specific file: `git add doc/blog-post-1.md`.
        *   Then the commit: `git commit -m 'docs(doc/blog-post-1): clarify usage of help command and piping mechanism'`.

        *   File is `doc/blog-post-1.md`.
        *   Current working directory matches repo root (`pwd` == `--show-toplevel`). No need for complex relative pathing, just use the filename as shown in git diff.

        ```bash
        git add doc/blog-post-1.md && \
        git commit -m "docs: clarify command usage and piping mechanism in blog post"
        ```

        *Wait*, let's refine the message to be more professional.
        The change adds info about `help` and clarifies that you can pipe between tools using cached results for idempotency.

        Commit type: `docs`.
        Message: "doc(blog-post): describe help command and pipeline/caching behavior"

        *   Single file? Yes.
        *   Conventional commits? Yes (`docs:`).
        *   Specific filename? Yes.
        *   Multiple commits? Not needed, change is cohesive (all describing usage in one doc file).

        ```bash
        git add doc/blog-post-1.md && \
        git commit -m "docs: update blog post to clarify help command and piping mechanism"
        ```
klotz@core:~/wip/answer🦶$
````
