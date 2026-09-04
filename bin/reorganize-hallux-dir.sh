#!/bin/bash

{ bx ls -lF;
 for file in *.md *.txt *.sh;
 do echo "$ headtail $file";
 cat "$file" | headtail -1;
 echo "";
 done;
} | ask 'Examine at all these provenance/experiment files in .hallux directory and organize them into subdirs by feature/task:
- Separate out projects that are widely separated by time (more than about one day) apart). Avoid redirecting stderr.
- The script should address all listed files.
- Use explicit filenames.
- Leave \*.json files alone.

Output a bash script with mkdir and mv commands.'


