#!/usr/bin/env bash
# Banc hors Studio d'a99 (2026-11-12, décision de Cantin : plus aucune protection des boutiques, défense par le
# propriétaire, PvP.KickRobCooldown = 60 s, mort dans la boutique d'un autre).
# Scénarios :
#   owner  : vrais PvPService, BatService, TheftAlertService… sur le faux Roblox et la mise en place du banc a32
#            (copie a37 : a37-banc/autres-bancs/a32-banc, lus sur place) : plus aucune protection, coup du
#            propriétaire sur un intrus mains vides en zone safe, sortie, 60 s sur cette boutique seulement
#            (retour, prise et porte refusés), autres boutiques ouvertes, coup d'un tiers sans effet, angle et
#            portée, voleur frappé dehors, fin des 60 s, mort dans une boutique, départ du propriétaire ;
#   client : vrais PvPService et PvPController sur le faux Roblox du banc a29 (copie a36 : a36-banc/autres-bancs/
#            a29-banc, lus sur place) : panneau « ROB AGAIN IN 60s » après une mort dans la boutique, invite coupée,
#            retour à la normale après 60 s.
#   bash run.sh [racine du dépôt] [scénarios…]   (défaut : /f/StealAShop)
# Avant la fusion d'a99 : « SAUTÉ » (0 vérification).
set -u
H="$(cd "$(dirname "$0")" && pwd)"
A32="$H/../a37-banc/autres-bancs/a32-banc"
A29="$H/../a36-banc/autres-bancs/a29-banc"
ROOT="${1:-/f/StealAShop}"
shift || true
SRC="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
SCENARIOS="${*:-owner client}"
if ! grep -q "KickRobCooldown" "$SRC/shared/Config/PvP.luau" 2>/dev/null; then
	echo "banc a99 SAUTÉ : cet arbre n'a pas encore la défense par le propriétaire"
	echo "banc a99 (défense par le propriétaire) : 0 vérification(s), 0 échec(s)"
	exit 0
fi
FILES32="shared $(if [ -d "$SRC/client/Controllers/UI" ]; then echo client/Controllers/UI; fi) server/Services/TheftAlertService.luau server/Services/PvPService.luau server/Services/BatService.luau server/Services/StatsService.luau server/Services/DisplayService.luau server/Services/PlotService.luau server/Services/WindowService.luau server/Services/CarryService.luau client/Controllers/TheftAlertController.luau client/Controllers/BatController.luau client/Controllers/ShelfBoxController.luau"
FILES29="shared server/Services/PvPService.luau server/Services/DisplayService.luau server/Services/PlotService.luau server/Services/WindowService.luau server/Services/CarryService.luau client/Controllers/PvPController.luau"

sources() {
	(cd "$SRC" && find $1 -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
}

OUTDIR="$(mktemp -d)"
trap 'rm -rf "$OUTDIR"' EXIT
total_checks=0
total_fails=0
for name in $SCENARIOS; do
	OUT="$OUTDIR/run.$name.luau"
	{
		if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; fi
		if [ "$name" = "client" ]; then
			cat "$A29/stubs.luau" "$A29/ext29.luau"
			cat "$A29/../stub-anticheat.luau"
			sources "$FILES29"
			cat "$A29/setup.luau"
		else
			cat "$A32/stubs.luau" "$A32/ext29.luau" "$A32/ext32.luau"
			cat "$A32/../stub-anticheat.luau"
			sources "$FILES32"
			cat "$A32/setup.luau"
		fi
		cat "$H/tests.$name.luau"
	} > "$OUT"
	out=$("$LUAU" "$(cygpath -w "$OUT")" 2>&1)
	line=$(printf '%s\n' "$out" | grep -E "^scénario .* : [0-9]+ vérification\(s\), [0-9]+ échec\(s\)$" | tail -1)
	if [ -z "$line" ]; then
		printf '%s\n' "$out" | tail -25
		echo "scénario $name : arrêté avant la fin (erreur ci-dessus)"
		total_fails=$((total_fails + 1))
		continue
	fi
	if [ "${VERBOSE:-}" = "1" ]; then
		printf '%s\n' "$out"
	else
		printf '%s\n' "$out" | grep -E "ÉCHEC|ERREUR|^    " || true
	fi
	c=$(printf '%s' "$line" | sed -E 's/.* : ([0-9]+) vérification.*/\1/')
	f=$(printf '%s' "$line" | sed -E 's/.*, ([0-9]+) échec.*/\1/')
	echo "  $name : $c contrôles, $f raté(s)"
	total_checks=$((total_checks + c))
	total_fails=$((total_fails + f))
done
echo "banc a99 (défense par le propriétaire) : $total_checks vérification(s), $total_fails échec(s)"
exit $((total_fails > 0))
