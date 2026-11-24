#!/usr/bin/env bash
# a174 (2026-11-15, vague 54) : comme a172-banc/corrige.sh, avec les correctifs de a174-banc/patches : le fichier Luau
# assemblé par un banc est corrigé juste avant d'être exécuté (faux luau.exe posé dans un HOME passager ; se combine
# avec les corrige.sh d'a158 et d'a172, qui appellent le luau.exe du HOME qu'ils reçoivent).
#   bash corrige.sh <nom> <commande du banc…>
#   - patches/<nom>.sed, s'il existe : appliqué au fichier assemblé.
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
	echo "exec \"$REAL_HOME/.rokit/bin/luau.exe\" \"\$@\""
} > "$T/.rokit/bin/luau.exe"
chmod +x "$T/.rokit/bin/luau.exe"
HOME="$T" "$@"
