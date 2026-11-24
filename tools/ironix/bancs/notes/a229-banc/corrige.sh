#!/usr/bin/env bash
# a229 (vague 69) : lance un banc existant avec les vigiles de nuit posés d'un coup (patches/pose-d-un-coup.sed),
# appliqué au fichier Luau assemblé juste avant son exécution (faux luau.exe dans un HOME passager, comme
# a158-banc/corrige.sh ; se combine avec lui).
#   bash corrige.sh <commande du banc…>
set -u
H="$(cd "$(dirname "$0")" && pwd)"
REAL_HOME="$HOME"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/.rokit/bin"
{
	echo '#!/usr/bin/env bash'
	echo 'f="$(cygpath -u "$1")"'
	echo "sed -E -i -f \"$H/patches/pose-d-un-coup.sed\" \"\$f\""
	echo "exec \"$REAL_HOME/.rokit/bin/luau.exe\" \"\$@\""
} > "$T/.rokit/bin/luau.exe"
chmod +x "$T/.rokit/bin/luau.exe"
HOME="$T" "$@"
