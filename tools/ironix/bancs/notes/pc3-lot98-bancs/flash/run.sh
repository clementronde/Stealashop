#!/usr/bin/env bash
# lot98 (petit chef 3) : lance un banc avec Config/CashFlash coupé dans le fichier qu'il lance (flash.pl). Un faux luau.exe
# de plus, puis celui d'avant.
#   bash run.sh <script du banc> <racine du dépôt> [arguments…]
set -u
D="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$1"
shift
REAL_HOME="$HOME"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/.rokit/bin"
{
	echo '#!/usr/bin/env bash'
	echo 'for a in "$@"; do'
	echo '	case "$a" in *.luau)'
	echo '		f="$(cygpath -u "$a")"'
	echo "		if [ -f \"\$f\" ]; then perl \"$D/flash.pl\" \"\$f\"; fi ;;"
	echo '	esac'
	echo 'done'
	echo "exec \"$REAL_HOME/.rokit/bin/luau.exe\" \"\$@\""
} > "$T/.rokit/bin/luau.exe"
chmod +x "$T/.rokit/bin/luau.exe"
HOME="$T" bash "$SCRIPT" "$@"
