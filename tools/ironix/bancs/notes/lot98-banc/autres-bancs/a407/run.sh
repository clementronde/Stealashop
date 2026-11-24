#!/usr/bin/env bash
# lot98-commun (petit chef 2, 24/11) : a407 est coupé dans le jeu (Features.RebirthTools = false, L-173, accord du grand chef).
# Son banc teste les outils allumés : il tourne sur une copie de src/ où l'interrupteur est remis à true (comme a401-banc-l299/rallume.pl).
set -u
N="$(cd "$(dirname "$0")/../../.." && pwd)"
ROOT="${1:-/f/StealAShop}"; ROOT="${ROOT%/src}"; shift || true
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
cp -r "$ROOT/src" "$T/src"
perl -pi -e 's/^(\s*)RebirthTools = false,/${1}RebirthTools = true,/' "$T/src/shared/Config/Features.luau"
grep -q 'RebirthTools = true,' "$T/src/shared/Config/Features.luau" || { echo "banc a407 : interrupteur introuvable dans la copie : 0 vérification(s), 1 échec(s)"; exit 1; }
bash "$N/a407-banc/run.sh" "$T" "$@"
