#!/usr/bin/env bash
# a201 (vague 61, L-192 : la récompense de zone de l'index n'est qu'un objet ; Index.ZoneCash retiré, plus
# d'argent ni de Vitesse, ZoneRewardText = « +WRENCH », SpeedReward et CashReward cachés) : lance un banc existant
# en corrigeant ses scénarios à la volée (même mécanisme que a191-banc/corrige.sh, qu'il enveloppe : les patches
# d'a191 passent d'abord, puis patches/index.sed et patches/<nom>.sed d'ici).
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
	echo "sed -E -i -f \"$H/patches/index.sed\" \"\$f\""
	if [ -f "$H/patches/$NAME.sed" ]; then
		echo "sed -E -i -f \"$H/patches/$NAME.sed\" \"\$f\""
	fi
	echo "exec \"$REAL_HOME/.rokit/bin/luau.exe\" \"\$@\""
} > "$T/.rokit/bin/luau.exe"
chmod +x "$T/.rokit/bin/luau.exe"
HOME="$T" "$@"
