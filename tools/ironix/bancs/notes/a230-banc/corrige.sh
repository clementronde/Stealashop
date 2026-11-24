#!/usr/bin/env bash
# a230 (vague 70, L-189) : lance un banc d'avant a230 en corrigeant à la volée son fichier assemblé avec patches/<nom>.sed
# (même mécanisme que a212-banc/corrige.sh : faux luau.exe dans un HOME passager, enchaîné sur le luau.exe du HOME d'avant).
#   - a75 : InventoryButton n'est plus dans UI.Twins.UI_HUD.
# Repli : arbre sans HeldIncomeController (avant la fusion d'a230) : le lanceur d'avant tel quel.
#   bash corrige.sh <nom> <lanceur d'avant> [racine du dépôt] [arguments…]
set -u
H="$(cd "$(dirname "$0")" && pwd)"
NAME="$1"
SCRIPT="$2"
shift 2
ROOT="${1:-/f/StealAShop}"
ROOT="${ROOT%/src}"
if [ ! -f "$ROOT/src/client/Controllers/HeldIncomeController.luau" ]; then
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
