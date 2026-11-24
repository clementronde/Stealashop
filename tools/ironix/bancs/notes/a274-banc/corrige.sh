#!/usr/bin/env bash
# a274 (vague GC2, audit a272 : H1 gamepass confirmé par Roblox, M2 codes côté serveur) : lance un banc existant en
# corrigeant son fichier Luau assemblé juste avant l'exécution (même principe que a158-banc/corrige.sh, qu'il peut
# envelopper : les faux luau.exe s'enchaînent par HOME).
#   bash corrige.sh <nom> <commande du banc…>
#   - patches/<nom>.pl, s'il existe : perl sur le fichier assemblé (sortie = fichier corrigé) ;
#   - patches/<nom>.pre.luau, s'il existe : ajouté en tête du fichier.
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
		echo "perl \"$H/patches/$NAME.pl\" \"\$f\" > \"\$f.a274\" && mv \"\$f.a274\" \"\$f\""
	fi
	if [ -f "$H/patches/$NAME.pre.luau" ]; then
		echo "cat \"$H/patches/$NAME.pre.luau\" \"\$f\" > \"\$f.a274\" && mv \"\$f.a274\" \"\$f\""
	fi
	echo "exec \"$REAL_HOME/.rokit/bin/luau.exe\" \"\$@\""
} > "$T/.rokit/bin/luau.exe"
chmod +x "$T/.rokit/bin/luau.exe"
HOME="$T" "$@"
