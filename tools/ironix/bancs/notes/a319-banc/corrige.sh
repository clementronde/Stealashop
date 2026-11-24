#!/usr/bin/env bash
# a319 : lance un banc existant en corrigeant son fichier Luau assemblé juste avant l'exécution (copie du principe
# d'a274-banc/corrige.sh ; les faux luau.exe s'enchaînent par HOME).
#   bash corrige.sh <nom> <commande du banc…>   (patches/<nom>.pl : perl sur le fichier assemblé)
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
	if [ -f "$H/patches/$NAME.pl" ]; then
		echo "perl \"$H/patches/$NAME.pl\" \"\$f\" > \"\$f.a319\" && mv \"\$f.a319\" \"\$f\""
	fi
	echo "exec \"$REAL_HOME/.rokit/bin/luau.exe\" \"\$@\""
} > "$T/.rokit/bin/luau.exe"
chmod +x "$T/.rokit/bin/luau.exe"
HOME="$T" "$@"
