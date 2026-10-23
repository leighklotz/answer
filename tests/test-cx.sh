#!/bin/bash

# basic: `$ cat` block per file, one CAT_ICON per file, one summary — nothing else
printf 'bin/cx.sh\n\n# comment line\nnope.py\n' | ./bin/cx.sh | head -2
#   stdout: $ cat bin/cx.sh / #!/usr/bin/env bash ...
#   stderr: ⚠️ skipping nope.py: no such file
#           🐱 cat bin/cx.sh
#           🔗 cx: 1 ingested, 1 skipped (… KiB)

# -n flips the echo and numbers lines
printf 'bin/cx.sh\n' | ./bin/cx.sh -n | head -2
#   $ cat -n bin/cx.sh
#        1  #!/usr/bin/env bash

# no trailing newline in a file — next echo still starts on its own line
printf 'no trailing newline' > /tmp/nnn.txt
printf '/tmp/nnn.txt\nbin/cx.sh\n' | ./bin/cx.sh | head -3
#   $ cat /tmp/nnn.txt
#   no trailing newline
#   $ cat bin/cx.sh

# strict, empty list, misuse (removed flags now count as unknown)
printf 'nope.py\n' | ./bin/cx.sh -s; echo $?   # 1, no summary
: | ./bin/cx.sh; echo $?                       # 0
./bin/cx.sh f; echo $?                         # 1
./bin/cx.sh --before='x' f; echo $?            # 1 (unknown flag)
