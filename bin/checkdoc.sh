#!/bin/bash -e

cd ~/wip/answer/doc/commands/

for file in *.md.new
do
  old="${file%.new}"
  echo "=== Analysis of $old -> $file ==="
  lx "$old" "${file}" | dreck | answer
  echo "== End Analysis $old -> $file ==="
  echo "----"
  echo ""
done
