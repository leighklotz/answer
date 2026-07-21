#!/bin/bash

cd ~/wip/answer/doc/commands/

for file in *.md.new
do
  echo "$file"
  lx "${file}" | ask 'briefly look for llm-dreck (whole file wrapped in backquotes, LLM intro/outro) and output wither CLEAN or DRECK'
  echo ""
done
