#!/usr/bin/env bash
# a309 : copie de a303-banc/corrige.sh, avec les correctifs de a309-banc/patches.
# le fichier Luau assemblé par un banc est corrigé juste avant d'être exécuté (faux luau.exe posé dans un HOME
# passager). Emboîtable : lancé autour du corrige.sh d'a176, ses correctifs passent d'abord, puis ceux-ci.
#   bash corrige.sh <nom> <commande du banc…>
#   - patches/<nom>.sed, s'il existe : appliqué au fichier assemblé ;
#   - patches/<nom>.pre.luau, s'il existe : ajouté en tête.
set -u
H="$(cd "$(dirname "$0")" && pwd)"
NAME="$1"
shift
REAL_HOME="$HOME"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/.rokit/bin"
{
	echo '#!/usr/bin/env bash'
	echo 'f="$(cygpath -u "$1")"'
	if [ -f "$H/patches/$NAME.sed" ]; then
		echo "sed -E -i -f \"$H/patches/$NAME.sed\" \"\$f\""
	fi
	if [ -f "$H/patches/$NAME.pre.luau" ]; then
		echo "cat \"$H/patches/$NAME.pre.luau\" \"\$f\" > \"\$f.a218\" && mv \"\$f.a218\" \"\$f\""
	fi
	echo "exec \"$REAL_HOME/.rokit/bin/luau.exe\" \"\$@\""
} > "$T/.rokit/bin/luau.exe"
chmod +x "$T/.rokit/bin/luau.exe"
HOME="$T" "$@"
