#!/usr/bin/env bash
# a264 (vague 78, 2026-11-20) : lance un banc existant en corrigeant à la volée son fichier assemblé (même mécanisme que
# a263-banc/corrige.sh : faux luau.exe dans un faux HOME ; les correctifs plus profonds, a262 et a263 compris, passent
# avant). Correctif : patches/<nom>.pl (perl, texte dans $t, fonctions has et lit). Arbre sans le correctif a264 de
# HeistController (invite « Steal » coupée tant que l'objet vole vers son rayon) : le banc tel quel.
#   bash corrige.sh <nom> <lanceur du banc> <racine du dépôt> [arguments…]
set -u
H="$(cd "$(dirname "$0")" && pwd)"
NAME="$1"
SCRIPT="$2"
shift 2
ROOT="${1:-/f/StealAShop}"
ROOT="${ROOT%/src}"
if ! grep -q "a264 (vague 78)" "$ROOT/src/client/Controllers/HeistController.luau" 2>/dev/null; then
	exec bash "$SCRIPT" "$@"
fi
REAL_HOME="$HOME"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/.rokit/bin"
{
	echo '#!/usr/bin/env bash'
	echo 'f="$(cygpath -u "$1")"'
	echo "if [ -f \"\$f\" ] && ! perl \"$H/patch.pl\" \"$H/patches/$NAME.pl\" \"\$f\"; then echo \"ÉCHEC a264 : correctif du banc $NAME pas appliqué à \$f : 0 vérification(s), 1 échec(s)\"; exit 1; fi"
	echo "exec \"$REAL_HOME/.rokit/bin/luau.exe\" \"\$@\""
} > "$T/.rokit/bin/luau.exe"
chmod +x "$T/.rokit/bin/luau.exe"
HOME="$T" bash "$SCRIPT" "$@"
