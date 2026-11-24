#!/usr/bin/env bash
# a170 (2026-11-15, vague 52, lot D : fin du colis porté côté client et contrat) : lance un banc existant en
# corrigeant ses scénarios à la volée (même mécanisme que a158-banc/corrige.sh, qu'il peut envelopper).
#   bash corrige.sh <nom> <commande du banc…>
# Un faux luau.exe, posé dans un HOME passager, corrige le fichier Luau assemblé puis appelle le luau.exe d'avant
# (le vrai, ou celui d'a158-banc/corrige.sh qui applique ensuite ses propres corrections) :
#   - patches/commun.sed : l'état d'inventaire n'a plus de Boxes (Shared/InventoryState) : les aides des bancs qui le
#     parcourent lisent une liste vide ;
#   - patches/<nom>.sed, s'il existe : les scénarios de ce banc qui vérifiaient ce qu'a170 retire (dit dans le fichier).
# Le lanceur de chaque banc (autres-bancs/<nom>/run.sh) n'appelle ce script que sur un arbre où a170 est fusionné.
set -u
H="$(cd "$(dirname "$0")" && pwd)"
NAME="$1"
shift
REAL_HOME="$HOME"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/.rokit/bin"
{
	echo '#!/usr/bin/env bash'
	echo 'f="$(cygpath -u "$1")"'
	echo "sed -E -i -f \"$H/patches/commun.sed\" \"\$f\""
	if [ -f "$H/patches/$NAME.sed" ]; then
		echo "sed -E -i -f \"$H/patches/$NAME.sed\" \"\$f\""
	fi
	echo "exec \"$REAL_HOME/.rokit/bin/luau.exe\" \"\$@\""
} > "$T/.rokit/bin/luau.exe"
chmod +x "$T/.rokit/bin/luau.exe"
HOME="$T" "$@"
