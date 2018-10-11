#!/bin/zsh

cdir="$(dirname "${0}")"

tmux \
    new-session  "cd '${cdir}/apps/global_registry' ; iex --sname reg -S mix ; read x" \; \
    split-window "cd '${cdir}/apps/ui'              ; iex --sname srv -S mix ; read x" \; \
    split-window "cd '${cdir}/web_ui'               ; elm reactor -a 0.0.0.0 ; read x" \; \
    select-layout even-vertical
