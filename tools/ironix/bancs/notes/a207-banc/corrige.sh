#!/usr/bin/env bash
# a207 (vague 63, L-201 : l'index v4 de Figma construit sous le nom UI_Index_v3) : lance un banc d'a201 en corrigeant
# ses scénarios à la volée, après les patches d'a191 et d'a201 (même mécanisme que a201-banc/corrige.sh : un faux
# luau.exe dans un HOME passager corrige le fichier assemblé avec patches/<nom>.sed, puis appelle le luau.exe d'avant).
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
	if [ -f "$H/patches/$NAME.sed" ]; then
		echo "sed -E -i -f \"$H/patches/$NAME.sed\" \"\$f\""
	fi
	echo "exec \"$REAL_HOME/.rokit/bin/luau.exe\" \"\$@\""
} > "$T/.rokit/bin/luau.exe"
chmod +x "$T/.rokit/bin/luau.exe"
HOME="$T" "$@"
