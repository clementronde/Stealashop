#!/usr/bin/env bash
# Banc hors Studio d a160 (2026-11-14, vague 50, L-165 points 1, 2 et 6 : hub, cadeau gratuit, invitation, bonus
# d amis, étiquettes BB_ZoneLabel). Faux Roblox minimal (fakes.luau) ; vraies sources : Config/DeepFreeze,
# Config/Hub, Shared/HubZone, HubService, HubController. Scénarios : hubzone (entrée et sortie, bonus 0 à 5 amis,
# textes), server (bonus d amis, accroche GetIncomeBonus, Idle et Wave du noob), client (UI_Rewards et invitation
# une fois par entrée, réapparition, cadeau qui flotte, étiquettes).
#   bash run.sh [racine du dépôt] [scénarios…]   (défaut : /f/StealAShop)
#   VERBOSE=1 bash run.sh                         écrit aussi les lignes ok
set -u
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop}"
shift || true
SRC="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
SCENARIOS="${*:-hubzone server client}"
FILES="shared/Config/DeepFreeze.luau shared/Config/Hub.luau shared/HubZone.luau server/Services/HubService.luau client/Controllers/HubController.luau"
if [ ! -f "$SRC/shared/HubZone.luau" ]; then
	echo "banc a160 (hub) : SAUTÉ, pas de Shared/HubZone dans $SRC (vague 50 pas encore fusionnée) : 0 vérification(s), 0 échec(s)"
	exit 0
fi

sources() {
	for f in $FILES; do
		printf 'SOURCES["%s"] = [==========[\n' "$f"; tr -d '\r' < "$SRC/$f"; printf '\n]==========]\n'
	done
}

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
total_checks=0
total_fails=0
for name in $SCENARIOS; do
	OUT="$TMP/run.$name.luau"
	{
		echo "SOURCES = {}"
		[ "${VERBOSE:-}" = "1" ] && echo "VERBOSE = true"
		sources
		cat "$H/fakes.luau" "$H/tests.$name.luau"
	} > "$OUT"
	out=$("$LUAU" "$(cygpath -w "$OUT")" 2>&1)
	line=$(printf '%s\n' "$out" | grep -E "^[0-9]+ vérification\(s\), [0-9]+ échec\(s\)$" | tail -1)
	if [ -z "$line" ]; then
		printf '%s\n' "$out" | tail -25
		echo "scénario $name : arrêté avant la fin (erreur ci-dessus)"
		total_fails=$((total_fails + 1))
		continue
	fi
	if [ "${VERBOSE:-}" = "1" ]; then
		printf '%s\n' "$out"
	else
		printf '%s\n' "$out" | grep -E "ÉCHEC|ERREUR" || true
	fi
	c=$(printf '%s' "$line" | sed -E 's/^([0-9]+) vérification.*/\1/')
	f=$(printf '%s' "$line" | sed -E 's/.*, ([0-9]+) échec.*/\1/')
	echo "  $name : $c contrôles, $f raté(s)"
	total_checks=$((total_checks + c))
	total_fails=$((total_fails + f))
done
echo "banc a160 (hub) : $total_checks vérification(s), $total_fails échec(s)"
exit $((total_fails > 0))
