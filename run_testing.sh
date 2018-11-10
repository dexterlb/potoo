#!/bin/zsh

cdir="$(dirname "${0}")"

tmux \
    new-session  "cd '${cdir}/potoo_global_registry' ; iex --sname reg -S mix ; read x" \; \
    split-window "cd '${cdir}/potoo_server'          ; iex --sname srv -S mix ; read x" \; \
    split-window "cd '${cdir}/web_ui'                ; elm reactor -a 0.0.0.0 ; read x" \; \
    select-layout even-vertical
