#!/bin/bash

INDEX="{{BIN_DIR}}/{{NAME}}.index"

sel=$(cut -d'|' -f1 "$INDEX" | fzf --query $1 --select-1  --exit-0)

[ -z "$sel" ] && exit

path=$(grep "^$sel|" "$INDEX" | head -n1 | cut -d'|' -f2)

open "$path"