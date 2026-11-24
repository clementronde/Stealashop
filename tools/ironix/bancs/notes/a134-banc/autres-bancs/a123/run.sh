#!/usr/bin/env bash
# Copie a134 (2026-11-14, vague 40, rééquilibrage v2 appliqué dans src/) : PV de la Fortune Tower (3.6B : 5 coups par seconde, dégâts de la zone 6 à 2M).
# Arbre sans le rééquilibrage (Balance.Stats.WalkPerDecade absent) : le banc d'avant tourne tel quel.
_A134_R="${1:-/f/StealAShop}"; _A134_F="$_A134_R/src/shared/Config/Balance.luau"; [ -f "$_A134_F" ] || _A134_F="$_A134_R/shared/Config/Balance.luau"
if ! grep -q "WalkPerDecade" "$_A134_F" 2>/dev/null; then exec bash "$(cd "$(dirname "$0")" && pwd)/../../../a123-banc/run.sh" "$@"; fi
# Banc hors Studio d'a123 (vague 37, 2026-11-14, L-108 point 8) : l'événement de la Fortune Tower.
#   Sur le faux Roblox et la mise en place du banc a27 (copie d'a51), lus sur place, plus
#   FortuneTowerService et FortuneTowerController (register.luau). Scénarios :
#   hook     : Studio, Features.FortuneTower = false : aucune vitrine automatique, crochet FortuneTest :
#              apparition (bloc V0, zone 6, PV, annonce), PV partagés, barre client, casse, butin, prise,
#              retrait ; Open, Seal, fin au temps, alerte de la nuit
#   schedule : Studio, interrupteur à true (camion coupé) : 40 à 60 min, pas seul, pas de nuit, pas avec un camion
#   prodoff  : hors Studio, coupé : rien, crochet ignoré
#   prodon   : hors Studio, à true : sans modèle pas de vitrine ; avec ENV_Event_FortuneVault : copie, scripts
#              retirés, butin sur LootSpawn_NN
#   bash run.sh [racine du dépôt] [scénarios…]   (défaut : /f/StealAShop)
set -u
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop}"
shift || true
SRC="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
SCENARIOS="${*:-hook schedule prodoff prodon}"
if [ ! -f "$SRC/server/Services/FortuneTowerService.luau" ]; then
	echo "banc a123 (Fortune Tower) : SAUTÉ, pas de FortuneTowerService dans $SRC (a123 pas encore fusionné) : 0 vérification(s), 0 échec(s)"
	exit 0
fi
A27="$H/../../../a51-banc/autres-bancs/a27-banc"

sources() {
	(cd "$SRC" && find "$@" -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
}

total_checks=0
total_fails=0
for name in $SCENARIOS; do
	: "${R1_D:=$(d="${R1_RUN:-${TMPDIR:-/tmp}/r1-bancs}"; mkdir -p "$d" && mktemp -d "$d/b.XXXXXX")}" "${R1_D:?r1 : dossier du banc introuvable}"; OUT="$R1_D/run.$name.luau"
	{
		if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; fi
		cat "$A27/stubs.luau" "$H/../../../a36-banc/autres-bancs/stub-anticheat.luau"
		sources shared server/Services/WindowService.luau server/Services/CarryService.luau server/Services/TruckEventService.luau server/Services/UnboxService.luau server/Services/ContractChecker.luau server/Services/FortuneTowerService.luau client/Controllers/HitController.luau client/Controllers/TruckController.luau client/Controllers/FortuneTowerController.luau
		if [ -f "$H/pre.$name.luau" ]; then cat "$H/pre.$name.luau"; fi
		cat "$A27/setup.luau" "$H/register.luau" "$H/tests.$name.luau"
	} > "$OUT"
	out=$("$LUAU" "$(cygpath -w "$OUT")" 2>&1)
	line=$(printf '%s\n' "$out" | grep -E "[0-9]+ vérification\(s\), [0-9]+ échec\(s\)$" | tail -1)
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
	c=$(printf '%s' "$line" | sed -E 's/.* : ([0-9]+) vérification.*/\1/')
	f=$(printf '%s' "$line" | sed -E 's/.*, ([0-9]+) échec.*/\1/')
	echo "  $name : $c contrôles, $f raté(s)"
	total_checks=$((total_checks + c))
	total_fails=$((total_fails + f))
done
echo "banc a123 (Fortune Tower) : $total_checks vérification(s), $total_fails échec(s)"
exit $((total_fails > 0))
