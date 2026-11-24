#!/usr/bin/env bash
# a232 (vague 70) : banc a196 (lanceur d avant : a221-banc/autres-bancs/a196/run.sh) ; sur un arbre avec a232, le blanc de
# l exposant d une copie de BB_Gain est fait d espaces insécables (U+00A0) : E1a lit le texte en les changeant en espaces
# (faux luau.exe dans un HOME passager qui corrige le fichier assemblé, comme a224-banc/corrige.sh). Sans a232 : tel quel.
#   bash run.sh [racine du dépôt]
N="$(cd "$(dirname "$0")/../../.." && pwd)"
ROOT="${1:-/f/StealAShop}"
ROOT="${ROOT%/src}"
if ! grep -q "NBSP = utf8.char(0xA0)" "$ROOT/src/client/Controllers/GainController.luau" 2>/dev/null; then
	exec bash "$N/a221-banc/autres-bancs/a196/run.sh" "$@"
fi
REAL_HOME="$HOME"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/.rokit/bin"
{
	echo '#!/usr/bin/env bash'
	echo 'f="$(cygpath -u "$1")"'
	echo 'if [ -f "$f" ]; then'
	echo "	perl -i -pe 's/^local txt = amount and amount\.Text or \"\"\$/local txt = (string.gsub(amount and amount.Text or \"\", utf8.char(0xA0), \" \")) -- a232/' \"\$f\""
	echo 'fi'
	echo "exec \"$REAL_HOME/.rokit/bin/luau.exe\" \"\$@\""
} > "$T/.rokit/bin/luau.exe"
chmod +x "$T/.rokit/bin/luau.exe"
HOME="$T" bash "$N/a221-banc/autres-bancs/a196/run.sh" "$@"
