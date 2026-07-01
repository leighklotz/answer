# History session

In addition to relying on the cache to generate identical results for identical inputs, you can also leverage the Bash history feature.

Here is an example where I flailed attempting to write a script to pass the source for a list of shell commands and bash functions to `help` to write usage documentation.

I started by manually and incrementally executing a bash for loop based on my previous command, which I edited using Meta-P in Bash. Then once I was close enough and tired of failing, I did this:

````bash

    klotz@tensor:~/wip/answer$ . commands/enable 
    klotz@tensor:~/wip/answer🦶$ history 15 | help write the loop i am trying to write to document all the commands. some are foo.sh and some are function foo in functions.sh so better choose which file to send to help as the source.
    💭```bash
    for cmd in answer ask bx help-commit help unfence; do
        fn="doc/$cmd.md"

        if [ -f "${cmd}.sh" ]; then
            # Command is a standalone script
            lx "./${cmd}.sh" README.md tests/story-test.sh doc/*.md | help "document the $cmd command for $fn" | unfence > "$fn"
        elif grep -qE "^[[:space:]]*(function[[:space:]]+)?$cmd[[:space:]]*\(" functions.sh; then
            # Command is a function in functions.sh
            # We source the file in a subshell so the function is available to the lx command
            (source functions.sh; lx "$cmd" README.md tests/story-test.sh doc/*.md | help "document the $cmd command for $fn" | unfence) > "$fn"
        else
            echo "Skipping $cmd: neither a script nor a function in functions.sh"
        fi
    done
    ```
    klotz@tensor:~/wip/answer🦶$ 
````
