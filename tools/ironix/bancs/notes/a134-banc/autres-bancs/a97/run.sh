#!/usr/bin/env bash
# Copie a134 (2026-11-14, vague 40, rééquilibrage v2 appliqué dans src/) : PV du camion = 100 × dégâts conseillés de sa zone (TruckEvent.MaxHP retiré).
# Arbre sans le rééquilibrage (Balance.Stats.WalkPerDecade absent) : le banc d'avant tourne tel quel.
_A134_R="${1:-/f/StealAShop}"; _A134_F="$_A134_R/src/shared/Config/Balance.luau"; [ -f "$_A134_F" ] || _A134_F="$_A134_R/shared/Config/Balance.luau"
if ! grep -q "WalkPerDecade" "$_A134_F" 2>/dev/null; then exec bash "$(cd "$(dirname "$0")" && pwd)/../../../a97-banc/run.sh" "$@"; fi
# Banc hors Studio d'a97 (vague 29, 2026-11-12, L-105 point 2) : arrivée du camion en roulant.
#   arrival : sur le faux Roblox et la mise en place du banc a27 (copie d'a51), lus sur place : camion livré
#             debout couché à sa place (Root debout), ArriveUpright, ArriveEndsAt, collisions coupées puis
#             remises, joueur resté dedans sorti par le côté ; copie locale qui roule, dérape, se couche,
#             conducteurs éjectés ; Explode et Leave pendant l'arrivée ; camion reçu après ; camion livré couché.
#   bash run.sh [racine du dépôt] [scénarios…]   (défaut : /f/StealAShop)
set -u
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop}"
shift || true
SRC="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
SCENARIOS="${*:-arrival}"
if ! grep -q "ArriveUpright" "$SRC/server/Services/TruckEventService.luau" 2>/dev/null; then
	echo "banc a97 (arrivée du camion) : SAUTÉ, pas d'arrivée en roulant dans $SRC (a97 pas encore fusionné) : 0 vérification(s), 0 échec(s)"
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
		sources shared server/Services/WindowService.luau server/Services/CarryService.luau server/Services/TruckEventService.luau server/Services/UnboxService.luau server/Services/ContractChecker.luau client/Controllers/HitController.luau client/Controllers/TruckController.luau
		cat "$A27/setup.luau" "$H/tests.$name.luau"
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
echo "banc a97 (arrivée du camion) : $total_checks vérification(s), $total_fails échec(s)"
exit $((total_fails > 0))
