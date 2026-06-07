#!/bin/bash
# Trusted RBT oracle: compiles the hand-written 2023 Coq red-black-tree workload
# (Impl.v + Spec.v) and prints each witness's verdict via `Compute`. The output
# lines look like:  = ("mut/prop"%string, Some true)
#
# Requires the opam switch built for this (Coq 8.15.0 + coq-quickchick 2.2.0):
#   brew install opam pkgconf gmp findutils
#   opam init -y --bare --disable-sandboxing
#   opam switch create etna-coq ocaml-base-compiler.4.14.2 -y
#   opam repo add coq-released https://coq.inria.fr/opam/released
#   opam install -y coq.8.15.0 coq-ext-lib coq-quickchick
set -e
export PATH=/opt/homebrew/bin:$PATH
eval "$(opam env --switch=etna-coq)"
cd "$(dirname "$0")"
for f in Impl QcEtna Spec Oracle; do coqc -Q . RBT "$f.v"; done
