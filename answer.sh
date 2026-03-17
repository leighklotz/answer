#!/bin/bash

if [ -t 0 ] && [ -n "${ANSWER}" ]; then
  printf "%s" "${ANSWER}" | jq -r '.[-1].content'
else
  jq -r '.[-1].content'
fi
