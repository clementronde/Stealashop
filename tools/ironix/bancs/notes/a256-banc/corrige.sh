#!/usr/bin/env bash
# a256 (vague 73, L-230 et L-242 point 5) : lance un banc d'avant en corrigeant à la volée son fichier assemblé (même
# mécanisme que a212-banc/corrige.sh : faux luau.exe dans un HOME passager, enchaîné sur celui d'avant) avec
# patches/a256.sed : Config/UiMotion WINDOW_TAS = false et Config/Tutorial MarkerBobClement = false. Les bancs a28, a75,
# a189, a209 et a212 lisent en dur l'ouverture 0,55, le flou 12 dans Lighting, la barre qui s'écarte, le HUD rendu
# boutique ouverte et le repère posé sur la cible : ils prouvent que false rend l'ancien comportement exactement.
# Repli : arbre sans WindowTas dans Config/UiMotion (avant la fusion d'a256) : le lanceur d'avant tel quel.
#   bash corrige.sh <nom> <lanceur d'avant> [racine du dépôt] [arguments…]
set -u
H="$(cd "$(dirname "$0")" && pwd)"
NAME="$1"
SCRIPT="$2"
shift 2
ROOT="${1:-/f/StealAShop}"
ROOT="${ROOT%/src}"
if ! grep -q 'WindowTas' "$ROOT/src/shared/Config/UiMotion.luau" 2>/dev/null; then
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
	[ -f "$H/patches/a256.sed" ] && echo "	sed -E -i -f \"$H/patches/a256.sed\" \"\$f\""
	echo "fi"
	echo "exec \"$REAL_HOME/.rokit/bin/luau.exe\" \"\$@\""
} > "$T/.rokit/bin/luau.exe"
chmod +x "$T/.rokit/bin/luau.exe"
HOME="$T" bash "$SCRIPT" "$@"
