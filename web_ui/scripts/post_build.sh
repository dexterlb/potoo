#!/bin/bash
set -eu

cdir="$(dirname "$(readlink -f "${0}")")"

cd "${cdir}"/..

rm -rvf dist/app.js # this is inlined into index.html and we don't need it
