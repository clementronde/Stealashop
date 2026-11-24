#!/usr/bin/env bash
# a203 (vague 62, le poids des objets) : lance un banc d'avant le poids en corrigeant à la volée son fichier assemblé
# (même mécanisme que a201-banc/corrige.sh : faux luau.exe dans un faux HOME). Les faux arbres de ces bancs n'ont ni
# Shared/ItemWeight ni Config/Weight : chaque require de ces deux modules est remplacé par leurs vraies sources en
# ligne (inline.pl), poids coupé (Features.SingleBoxReveal = false : le comportement que ces bancs vérifient ; le poids
# en marche est vérifié par a203-banc). Arbre sans Shared/ItemWeight : le banc tel quel.
#   bash corrige.sh <nom> <lanceur du banc> <racine du dépôt> [arguments…]
set -u
H="$(cd "$(dirname "$0")" && pwd)"
NAME="$1"
SCRIPT="$2"
shift 2
ROOT="${1:-/f/StealAShop}"
ROOT="${ROOT%/src}"
if [ ! -f "$ROOT/src/shared/ItemWeight.luau" ]; then
	exec bash "$SCRIPT" "$@"
fi
REAL_HOME="$HOME"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/.rokit/bin"
# Expressions : (function() <source> end)(), types exportés rendus locaux, requires internes remplacés.
{
	printf '(function() --a203-poids-en-ligne\n'
	tr -d '\r' < "$ROOT/src/shared/Config/Weight.luau" | sed -E 's/^export type /type /; s/require\(script\.Parent\.DeepFreeze\)/(function(value) return value end)/'
	printf '\nend)()'
} > "$T/weight.expr"
{
	printf '(function() --a203-poids-en-ligne\n'
	tr -d '\r' < "$ROOT/src/shared/ItemWeight.luau" | sed -E 's/^export type /type /; s/^local Config = script\.Parent\.Config$/local Config = nil/; s/require\(Config\.Features\)/({ SingleBoxReveal = false })/' \
		| A203_W="$T/weight.expr" perl -pe 'BEGIN { local $/; open(F, "<", $ENV{A203_W}); $w = <F>; close F } s/require\(Config\.Weight\)/$w/'
	printf '\nend)()'
} > "$T/itemweight.expr" 2>/dev/null
{
	echo '#!/usr/bin/env bash'
	echo 'f="$(cygpath -u "$1")"'
	echo "[ -f \"\$f\" ] && perl \"$H/inline.pl\" \"$T/itemweight.expr\" \"$T/weight.expr\" \"\$f\""
	echo "exec \"$REAL_HOME/.rokit/bin/luau.exe\" \"\$@\""
} > "$T/.rokit/bin/luau.exe"
chmod +x "$T/.rokit/bin/luau.exe"
HOME="$T" bash "$SCRIPT" "$@"
