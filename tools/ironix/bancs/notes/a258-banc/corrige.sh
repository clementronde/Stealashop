#!/usr/bin/env bash
# a258 (vague 74, L-259) : lance un banc d'avant en corrigeant à la volée son fichier assemblé (même mécanisme que
# a256-banc/corrige.sh : faux luau.exe dans un HOME passager) avec patches/a258.sed : Config/UiMotion WINDOW_E = false.
# Le banc a256 lit en dur l'ouverture 0,84 → 1, le flou 16 et UI_Offline sans flou : il prouve que false rend la vague 73.
# Repli : arbre sans WindowE dans Config/UiMotion (avant la fusion d'a258) : le lanceur d'avant tel quel.
#   bash corrige.sh <nom> <lanceur d'avant> [racine du dépôt] [arguments…]
set -u
H="$(cd "$(dirname "$0")" && pwd)"
NAME="$1"
SCRIPT="$2"
shift 2
ROOT="${1:-/f/StealAShop}"
ROOT="${ROOT%/src}"
if ! grep -q 'WindowE' "$ROOT/src/shared/Config/UiMotion.luau" 2>/dev/null; then
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
	[ -f "$H/patches/a258.sed" ] && echo "	sed -E -i -f \"$H/patches/a258.sed\" \"\$f\""
	echo "fi"
	echo "exec \"$REAL_HOME/.rokit/bin/luau.exe\" \"\$@\""
} > "$T/.rokit/bin/luau.exe"
chmod +x "$T/.rokit/bin/luau.exe"
HOME="$T" bash "$SCRIPT" "$@"
