#!/bin/bash
cd "$(dirname "$(readlink -f "${0}")")"
go run -mod=vendor github.com/DexterLB/potoo/toys/fidget
