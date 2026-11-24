#!/usr/bin/env bash
# a241 (vague 72, L-219 point 2) : banc a241, scénario exit-chase (a241-banc/exit), lancé par a202-banc/ancien.sh
# (Features.SingleBoxReveal = false, comme le banc a110 : on ouvre un colis puis on prend l'objet sur le rayon).
# Arbre sans Chase.ChaseOnEmptyExit (avant la fusion d'a241) : « SAUTÉ ».
S="$(cd "$(dirname "$0")/.." && pwd)"
ARG="${1:-/f/StealAShop}"
REPO="${ARG%/src}"
if ! grep -q "ChaseOnEmptyExit = true" "$REPO/src/shared/Config/Chase.luau" 2>/dev/null; then
	echo "banc a241 : SAUTÉ (pas de Chase.ChaseOnEmptyExit = true dans cet arbre) : 0 vérification(s), 0 échec(s)"
	exit 0
fi
exec bash "$S/a202-banc/ancien.sh" "$S/a241-banc/exit/run.sh" repo "$REPO"
