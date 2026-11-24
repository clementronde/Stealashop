#!/usr/bin/env bash
# a196 (vague 60) : copie de a190-banc/corrige.sh avec les correctifs d'ici : un faux luau.exe dans un HOME passager
# applique patches/<nom>.sed au fichier Luau assemblé puis appelle le luau.exe d'avant (il peut en envelopper un autre).
#   bash corrige.sh <nom> <commande du banc…>
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
	echo "sed -E -i -f \"$H/patches/$NAME.sed\" \"\$f\""
	echo "exec \"$REAL_HOME/.rokit/bin/luau.exe\" \"\$@\""
} > "$T/.rokit/bin/luau.exe"
chmod +x "$T/.rokit/bin/luau.exe"
HOME="$T" "$@"
