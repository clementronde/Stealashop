#!/usr/bin/env bash
# a305 (22/11) : lance un banc existant en corrigeant le fichier Luau assemblé (même mécanisme que f56-banc/corrige.sh) :
# un faux luau.exe dans un HOME passager applique le fichier sed donné, puis appelle le luau.exe d'avant.
#   bash corrige.sh <fichier sed> <commande du banc…>
set -u
SED="$1"
shift
REAL_HOME="$HOME"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/.rokit/bin"
{
	echo '#!/usr/bin/env bash'
	echo 'f="$(cygpath -u "$1")"'
	echo "sed -E -i -f \"$SED\" \"\$f\""
	echo "exec \"$REAL_HOME/.rokit/bin/luau.exe\" \"\$@\""
} > "$T/.rokit/bin/luau.exe"
chmod +x "$T/.rokit/bin/luau.exe"
HOME="$T" "$@"
