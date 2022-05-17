#!/bin/bash
set -eu

cdir="$(dirname "$(readlink -f "${0}")")"

cd "${cdir}"/..

rm -rvf dist
