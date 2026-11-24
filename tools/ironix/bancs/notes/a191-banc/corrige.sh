#!/usr/bin/env bash
# a191 (2026-11-15, vague 59, L-183 : récompense de zone de l'Index en valeurs fixes, plus de +5 % de revenus ni de
# +3 % de vitesse ; IndexService.GetIncomeBonus et GetSpeedMultiplier, Index.ZoneBonus, ZoneSpeedBonus,
# ZoneCashMinutes et SpeedMultiplier retirés) : lance un banc existant en corrigeant ses scénarios à la volée
# (même mécanisme que a170-banc/corrige.sh, qu'il peut envelopper).
#   bash corrige.sh <nom> <commande du banc…>
# Un faux luau.exe, posé dans un HOME passager, corrige le fichier Luau assemblé (patches/index.sed, puis
# patches/<nom>.sed s'il existe) puis appelle le luau.exe d'avant (le vrai, ou le faux d'un autre corrige.sh).
# Le lanceur de chaque banc (autres-bancs/<nom>/run.sh) n'appelle ce script que sur un arbre où a191 est fusionné.
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
