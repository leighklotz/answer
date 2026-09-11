#!/bin/bash

hx cache disable

for file in "$(hx cache show).json"
do
    echo -n "${file}: "
    hx what - < "$file" | ask "give a short title for this chat, no other output" > "${file}.txt"
    echo ""
done
