#!/usr/bin/env bash
# a231 (vague 70) : lance un banc existant en corrigeant ses scénarios à la volée (même principe que a158-banc/corrige.sh,
# sans ses motifs communs) : un faux luau.exe, posé dans un HOME passager, applique patches/<nom>.sed au fichier assemblé
# puis appelle le luau d'avant (qui peut être lui-même un faux d'un autre corrige.sh).
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
