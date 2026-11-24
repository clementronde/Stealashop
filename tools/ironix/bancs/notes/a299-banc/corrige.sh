#!/usr/bin/env bash
# a299 (cases de la caisse figées, survol qui grossit autour du centre) : lance un banc d'avant en corrigeant à la volée
# son fichier assemblé (même mécanisme que a256-banc/corrige.sh : faux luau.exe dans un HOME passager, enchaîné sur celui
# d'avant) avec patches/<nom>.sed :
#   - a209 : S3 lisait en dur ± 4 px pour les cases (L-204) ; il lit maintenant Config/ShopFx.Crate.OddBob (0 depuis a299).
#   - a60 : M4d lisait la Position de l'Icon décalé dans son AnchorPoint (0, 0) ; il passe par Motion.Placed (Icon recentré).
# Repli : arbre sans OddBob = 0 dans Config/ShopFx (avant la fusion d'a299) : le lanceur d'avant tel quel.
#   bash corrige.sh <nom> <lanceur d'avant> [racine du dépôt] [arguments…]
set -u
H="$(cd "$(dirname "$0")" && pwd)"
NAME="$1"
SCRIPT="$2"
shift 2
ROOT="${1:-/f/StealAShop}"
ROOT="${ROOT%/src}"
if ! grep -q 'OddBob = 0,' "$ROOT/src/shared/Config/ShopFx.luau" 2>/dev/null; then
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
