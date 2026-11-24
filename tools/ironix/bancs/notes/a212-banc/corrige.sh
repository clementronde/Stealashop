#!/usr/bin/env bash
# a212 (vague 64, écrans comme dans la vidéo : ouverture 0,38 s Back Out, fermeture Back In 0,2 s, cartes à +230 ms) :
# lance un banc d'avant la vague 64 en corrigeant à la volée son fichier assemblé (même mécanisme que f57-banc/corrige.sh :
# faux luau.exe dans un HOME passager, enchaîné sur le luau.exe du HOME d'avant, donc sur les correctifs des lanceurs
# d'avant) avec patches/<nom>.sed :
#   - a19 : les attentes Z2, Z4 et Z5 couvrent les nouvelles durées (0,38 s et 0,2 s au lieu de 0,14 et 0,09) ;
#   - a37 : M3b, la fermeture prend d'abord son élan (Back In : l'échelle passe au-dessus de 1) ;
#   - a75, a189 et a209 : leurs tests lisent les valeurs d'avant en dur (L-094, L-188, cases de la caisse) → l'interrupteur
#     Config/UiMotion VIDEO_RHYTHM mis à false dans le fichier assemblé : ils prouvent que false rend l'ancien rythme
#     exactement ; le nouveau rythme est vérifié par le banc a212.
# Repli : arbre sans VideoRhythm dans Config/UiMotion (avant la fusion d'a212) : le lanceur d'avant tel quel.
#   bash corrige.sh <nom> <lanceur d'avant> [racine du dépôt] [arguments…]
set -u
H="$(cd "$(dirname "$0")" && pwd)"
NAME="$1"
SCRIPT="$2"
shift 2
ROOT="${1:-/f/StealAShop}"
ROOT="${ROOT%/src}"
if ! grep -q 'VideoRhythm' "$ROOT/src/shared/Config/UiMotion.luau" 2>/dev/null; then
	exec bash "$SCRIPT" "$@"
fi
REAL_HOME="$HOME"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/.rokit/bin"
{
	echo '#!/usr/bin/env bash'
	echo 'f="$(cygpath -u "$1")"'
	echo "if [ -f \"\$f\" ]; then"
	[ -f "$H/patches/$NAME.sed" ] && echo "	sed -E -i -f \"$H/patches/$NAME.sed\" \"\$f\""
	echo "fi"
	echo "exec \"$REAL_HOME/.rokit/bin/luau.exe\" \"\$@\""
} > "$T/.rokit/bin/luau.exe"
chmod +x "$T/.rokit/bin/luau.exe"
HOME="$T" bash "$SCRIPT" "$@"
