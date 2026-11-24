#!/usr/bin/env bash
# lot98 (petit chef 3) : lance un banc avec UserInputService = {} ajouté aux services de son faux Roblox (uis.pl ;
# a419 : Shared/Gamepad le demande au chargement). Un faux luau.exe de plus, puis celui d'avant.
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
	echo "		if [ -f \"\$f\" ]; then perl \"$D/uis.pl\" \"\$f\"; fi ;;"
	echo '	esac'
	echo 'done'
	echo "exec \"$REAL_HOME/.rokit/bin/luau.exe\" \"\$@\""
} > "$T/.rokit/bin/luau.exe"
chmod +x "$T/.rokit/bin/luau.exe"
HOME="$T" bash "$SCRIPT" "$@"
