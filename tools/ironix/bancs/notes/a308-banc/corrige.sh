#!/usr/bin/env bash
# a308 (22/11 : boutons qui remplissent leur parent branchés dans les écrans de Config/UiMotion.Hover.FillParentScreens) : lance
# un banc d'avant en corrigeant à la volée son fichier assemblé (même mécanisme que a299-banc/corrige.sh : faux luau.exe
# dans un HOME passager, enchaîné sur celui d'avant) avec patches/<nom>.sed :
#   - a60 : F1f attendait le calque plein cadre NavLayer de UI_WeaponShop laissé de côté ; il est maintenant branché
#     (UI_WeaponShop est dans la liste) : F1f vérifie qu'il l'est. Le calque d'un écran hors liste reste écarté (banc a308).
# Repli : arbre sans FillParentScreens dans Config/UiMotion (avant la fusion d'a308) : le lanceur d'avant tel quel.
#   bash corrige.sh <nom> <lanceur d'avant> [racine du dépôt] [arguments…]
set -u
H="$(cd "$(dirname "$0")" && pwd)"
NAME="$1"
SCRIPT="$2"
shift 2
ROOT="${1:-/f/StealAShop}"
ROOT="${ROOT%/src}"
if ! grep -q 'FillParentScreens = ' "$ROOT/src/shared/Config/UiMotion.luau" 2>/dev/null; then
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
