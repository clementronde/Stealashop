#!/usr/bin/env bash
# a430 (L-330) : lance un banc en ajoutant à son faux Roblox Inst.IsDescendantOf (descendant.pl, appliqué au fichier
# assemblé par un faux luau.exe dans un faux HOME, comme a262-banc/corrige.sh). Arbre sans le filtre du Workspace dans
# LeaderboardService : le banc tel quel.
#   bash corrige.sh <lanceur du banc> <racine du dépôt> [arguments…]
set -u
H="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$1"
shift
ROOT="${1:-/f/StealAShop}"
ROOT="${ROOT%/src}"
if ! grep -q "IsDescendantOf(Workspace)" "$ROOT/src/server/Services/LeaderboardService.luau" 2>/dev/null; then
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
	echo "		if [ -f \"\$f\" ] && ! perl \"$H/descendant.pl\" \"\$f\"; then echo \"ÉCHEC a430 : descendant.pl pas appliqué à \$f : 0 vérification(s), 1 échec(s)\"; exit 1; fi ;;"
	echo '	esac'
	echo 'done'
	echo "exec \"$REAL_HOME/.rokit/bin/luau.exe\" \"\$@\""
} > "$T/.rokit/bin/luau.exe"
chmod +x "$T/.rokit/bin/luau.exe"
HOME="$T" bash "$SCRIPT" "$@"
