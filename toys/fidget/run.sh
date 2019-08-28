#!/bin/bash
cd "$(dirname "$(readlink -f "${0}")")"
if [[ "${1}" == test ]]; then
    go test -mod=vendor ./...
fi

go run -mod=vendor github.com/DexterLB/potoo/toys/fidget
