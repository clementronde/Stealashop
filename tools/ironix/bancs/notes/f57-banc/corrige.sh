#!/usr/bin/env bash
# fusion57 (vague 63) : lance un banc d'avant la vague 63 en corrigeant à la volée son fichier assemblé (même mécanisme
# que f56-banc/corrige.sh et a203-banc/corrige.sh : faux luau.exe dans un HOME passager, enchaîné sur le luau.exe du HOME
# d'avant, donc sur les correctifs des lanceurs d'avant) :
#   - Config/Boosts en ligne : Config/Monetization le requiert depuis a208, les faux arbres d'a98, a130 et a167 ne l'ont pas
#     (expression (function() <source> end)(), types rendus locaux, DeepFreeze neutre) ;
#   - patches/<nom>.sed s'il existe (a171 : 6 packs d'a208 ; a191 et a209 : attribut Diamonds publié par DataService).
# Repli : arbre sans la marque de fusion57 du banc (voir COND) : le lanceur d'avant tel quel.
#   bash corrige.sh <nom> <lanceur d'avant> [racine du dépôt] [arguments…]
set -u
H="$(cd "$(dirname "$0")" && pwd)"
NAME="$1"
SCRIPT="$2"
shift 2
ROOT="${1:-/f/StealAShop}"
ROOT="${ROOT%/src}"
case "$NAME" in
	a171) COND() { grep -q 'Cash720' "$ROOT/src/shared/Config/Monetization.luau" 2>/dev/null; } ;;
	a191 | a209) COND() { grep -q 'DIAMONDS_ATTRIBUTE' "$ROOT/src/server/Services/DataService.luau" 2>/dev/null; } ;;
	*) COND() { grep -q 'require(script.Parent.Boosts)' "$ROOT/src/shared/Config/Monetization.luau" 2>/dev/null; } ;;
esac
if ! COND; then
	exec bash "$SCRIPT" "$@"
fi
REAL_HOME="$HOME"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/.rokit/bin"
: > "$T/boosts.expr"
if grep -q 'require(script.Parent.Boosts)' "$ROOT/src/shared/Config/Monetization.luau" 2>/dev/null; then
	{
		printf '(function() --f57-boosts-en-ligne\n'
		tr -d '\r' < "$ROOT/src/shared/Config/Boosts.luau" | sed -E 's/^export type /type /; s/require\(script\.Parent\.DeepFreeze\)/(function(value) return value end)/'
		printf '\nend)()'
	} > "$T/boosts.expr"
fi
{
	echo '#!/usr/bin/env bash'
	echo 'f="$(cygpath -u "$1")"'
	echo "if [ -f \"\$f\" ]; then"
	echo "	[ -s \"$T/boosts.expr\" ] && F57_B=\"$T/boosts.expr\" perl -0777 -i -pe 'BEGIN { local \$/; open(F, \"<\", \$ENV{F57_B}); \$b = <F>; close F } next if index(\$_, \"--f57-boosts-en-ligne\") >= 0; s/require\(script\.Parent\.Boosts\)/\$b/g' \"\$f\""
	[ -f "$H/patches/$NAME.sed" ] && echo "	sed -E -i -f \"$H/patches/$NAME.sed\" \"\$f\""
	echo "fi"
	echo "exec \"$REAL_HOME/.rokit/bin/luau.exe\" \"\$@\""
} > "$T/.rokit/bin/luau.exe"
chmod +x "$T/.rokit/bin/luau.exe"
HOME="$T" bash "$SCRIPT" "$@"
