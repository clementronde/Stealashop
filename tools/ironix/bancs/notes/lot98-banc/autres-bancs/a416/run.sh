#!/usr/bin/env bash
# lot98-commun (petit chef 2, 24/11) : Chase.ClientView.BaseSeconds passe de 0,25 à 0,34 (mesure du Play f98, accord du grand chef).
# Le banc a416 simule des tampons dont la somme vaut 0,25 s et écrit ses attentes avec 0,25 : il tourne sur une copie de src/
# remise à 0,25 et DisplaySeconds 0,12 (il vérifie le mécanisme ; la valeur, elle, se règle en Play).
set -u
N="$(cd "$(dirname "$0")/../../.." && pwd)"
ROOT="${1:-/f/StealAShop}"; ROOT="${ROOT%/src}"; shift || true
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
cp -r "$ROOT/src" "$T/src"
perl -pi -e 's/^(\s*)BaseSeconds = 0\.34,/${1}BaseSeconds = 0.25,/' "$T/src/shared/Config/Chase.luau"
perl -pi -e 's/^(\s*)DisplaySeconds = 0\.15,/${1}DisplaySeconds = 0.12,/' "$T/src/shared/Config/Chase.luau"
bash "$N/a416-banc/run.sh" "$T" "$@"
