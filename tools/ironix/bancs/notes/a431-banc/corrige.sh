#!/usr/bin/env bash
# a431 (24/11, L-332) : copie de lot98-banc/corrige.sh, avec a431-banc/patches (appliqués après ceux du lot 98).
# lot98-commun (petit chef 2, 24/11) : copie de lot96-banc/corrige.sh, avec lot98-banc/patches.
# lot96 (petit chef 2, 23/11, suite du groupe lot96 + lot97) : même principe que a274-banc/corrige.sh (les faux luau.exe s enchaînent par HOME).
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
		echo "perl \"$H/patches/$NAME.pl\" \"\$f\" > \"\$f.a431c\" && mv \"\$f.a431c\" \"\$f\""
	fi
	if [ -f "$H/patches/$NAME.pre.luau" ]; then
		echo "cat \"$H/patches/$NAME.pre.luau\" \"\$f\" > \"\$f.a431c\" && mv \"\$f.a431c\" \"\$f\""
	fi
	echo "exec \"$REAL_HOME/.rokit/bin/luau.exe\" \"\$@\""
} > "$T/.rokit/bin/luau.exe"
chmod +x "$T/.rokit/bin/luau.exe"
HOME="$T" "$@"
