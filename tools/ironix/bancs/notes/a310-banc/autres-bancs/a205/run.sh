#!/usr/bin/env bash
# a310 (22/11) : copie de a205-banc/run.sh ; hud3 et lock lus dans a205-banc, tapis par la copie d ici (run.tapis.sh).
# Banc a205 (vague 63) : hud3 (HUD v3 sans menu « More », TopLeftRow calé sur TopbarInset, RebirthButton, boutons
# trouvés par nom ; copie a205 du banc a190), lock (LockIcon de BB_AntiTheft caché à « UNLOCKED! » ; chaîne d a178),
# tapis (tapis élargis ×1,5, L-207 ; harnais d a180). Arbre sans Config/Hud.TopLeftRow : « SAUTÉ ».
#   bash run.sh [racine du dépôt]   (défaut : /f/StealAShop)
set -u
H="$(cd "$(dirname "$0")" && pwd)"
A205="$H/../../../a205-banc"
ROOT="${1:-/f/StealAShop}"
if ! grep -q "SideEntryMargin =" "${ROOT%/src}/src/shared/Config/Training.luau" 2>/dev/null; then
	exec bash "$A205/run.sh" "$@" # avant a310 : le banc d'origine
fi
if ! grep -q "TopLeftRow" "$ROOT/src/shared/Config/Hud.luau" 2>/dev/null; then
	echo "banc a205 (HUD v3, cadenas, tapis ×1,5) : SAUTÉ, a205 pas encore fusionné : 0 vérification(s), 0 échec(s)"
	exit 0
fi
checks=0
fails=0
for part in "$A205/autres-bancs/a190/run.sh $ROOT hud3" "$A205/run.lock.sh $ROOT" "$H/run.tapis.sh $ROOT"; do
	set -- $part
	script="$1"
	shift
	out=$(bash "$script" "$@" 2>&1)
	printf '%s\n' "$out" | grep -vE "^banc .*vérification" || true
	line=$(printf '%s\n' "$out" | grep -E "[0-9]+ vérification\(s\), [0-9]+ échec\(s\)$" | tail -1)
	if [ -z "$line" ]; then
		echo "  $script : pas de ligne de résultat"
		fails=$((fails + 1))
		continue
	fi
	echo "  $line"
	c=$(printf '%s' "$line" | sed -E 's/.* ([0-9]+) vérification.*/\1/')
	f=$(printf '%s' "$line" | sed -E 's/.*, ([0-9]+) échec.*/\1/')
	checks=$((checks + c))
	fails=$((fails + f))
done
echo "banc a205 (HUD v3, cadenas, tapis ×1,5) : $checks vérification(s), $fails échec(s)"
exit $((fails > 0))
