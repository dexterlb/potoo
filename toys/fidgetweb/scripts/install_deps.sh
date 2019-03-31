#!/bin/sh
if [ package.json -ot node_modules/marker ]; then
    echo "nothing to update"
else
    npm install && touch node_modules/marker
fi
