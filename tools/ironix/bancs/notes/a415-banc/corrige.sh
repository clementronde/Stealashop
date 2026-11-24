#!/usr/bin/env bash
# a415 (23/11, demande de Cantin : retrait du lâcher volontaire) : lance un banc existant avec un faux luau.exe qui
# applique a415-banc/patches/<nom>.pl à chaque fichier .luau passé à luau avant de le lancer (même principe
# qu'a262-banc/corrige.sh et que le faux luau.exe d'a265).
# Arbre d'avant a415 (src/server/Services/DropService.luau encore là) : le banc tel quel.
#   bash corrige.sh <nom> <lanceur du banc> [racine du dépôt] [scénarios…]
set -u
H="$(cd "$(dirname "$0")" && pwd)"
NAME="$1"
SCRIPT="$2"
shift 2
ROOT="${1:-/f/StealAShop}"
ROOT="${ROOT%/src}"
if [ -f "$ROOT/src/server/Services/DropService.luau" ]; then
	exec bash "$SCRIPT" "$@"
fi
REAL_HOME="$HOME"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/.rokit/bin"
{
	echo '#!/usr/bin/env bash'
	echo 'for a in "$@"; do'
	echo '	case "$a" in *.luau)'
	echo '		f="$(cygpath -u "$a")"'
	echo "		if [ -f \"\$f\" ] && ! perl \"$H/patches/$NAME.pl\" \"\$f\"; then echo \"ÉCHEC a415 : correctif du banc $NAME pas appliqué à \$f : 0 vérification(s), 1 échec(s)\"; exit 1; fi ;;"
	echo '	esac'
	echo 'done'
	echo "exec \"$REAL_HOME/.rokit/bin/luau.exe\" \"\$@\""
} > "$T/.rokit/bin/luau.exe"
chmod +x "$T/.rokit/bin/luau.exe"
HOME="$T" bash "$SCRIPT" "$@"
