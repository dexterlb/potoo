#!/bin/zsh

cdir="$(dirname "${0}")"

tmux \
    new-session  "cd '${cdir}/potoo_global_registry' ; iex --sname reg -S mix ; read x" \; \
    split-window "cd '${cdir}/potoo_server'          ; iex --sname srv -S mix ; read x" \; \
    split-window "cd '${cdir}/web_ui'                ; npm run install-deps && npm run serve ; read x" \; \
    select-layout even-vertical
