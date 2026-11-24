#!/usr/bin/env bash
# Banc hors Studio d'a229 (vague 69, gel du serveur à la tombée de la nuit) : rayons remplis un magasin par image
# (StoreHeistService.RefillAll(true)) et vigiles de nuit posés un par image (GuardService.StartNightPatrol).
# Mesure aussi (lignes « MESURE ») le temps de la plus longue image et les instances créées par image (faux Roblox :
# temps Luau seulement, pas le moteur).
#   refill  harnais du banc a103 (vrai StoreHeistService, 12 magasins de 10 rayons comme la map DEV)
#   night   harnais du banc a21-night (copie a94 ; vrais NightCycleService et GuardService, StoreHeistService bouchonné)
#   bash run.sh [racine du dépôt]        MESURE=1 : lance aussi sur un arbre d'avant a229 (mesure « avant »)
# Avant a229 (RefillAll sans « spread ») : « SAUTÉ ».
set -u
H="$(cd "$(dirname "$0")" && pwd)"
S="$H/.."
ROOT="${1:-/f/StealAShop}"
ROOT="${ROOT%/src}"
SRC="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
LABEL="banc a229 (tombée de la nuit étalée)"
if [ "${MESURE:-}" != "1" ] && ! grep -q "RefillAll(spread" "$SRC/server/Services/StoreHeistService.luau" 2>/dev/null; then
	echo "$LABEL : SAUTÉ (avant a229) : 0 vérification(s), 0 échec(s)"
	exit 0
fi
sources() {
	(cd "$SRC" && find $1 -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
}
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
BASE="$S/a66-banc/autres-bancs/a30-banc"
{
	cat "$BASE/stubs.luau" "$BASE/../stub-anticheat.luau"
	sources "shared server/Services/BatService.luau server/Services/CarryService.luau server/Services/GuardService.luau server/Services/StoreHeistService.luau server/Services/WindowService.luau server/Services/ToolService.luau server/Services/StatsService.luau server/Services/TruckEventService.luau client/Controllers/BatController.luau client/Controllers/HitController.luau client/Controllers/TruckController.luau"
	cat "$BASE/setup.luau" "$S/a103-banc/head.luau" "$H/tests.refill.luau"
} > "$T/refill.luau"
N="$S/a94-banc/autres-bancs/a21-night"
{
	cat "$N/stubs.luau" "$N/../stub-anticheat.luau"
	printf '\nRIG_MODE = "roblox"\n'
	sources "shared server/Services/GuardService.luau server/Services/NightCycleService.luau server/Services/ReturnBaseService.luau client/Controllers/ChaseController.luau"
	cat "$S/a147-banc/retour-base-actif.luau" "$N/tests.head.luau" "$H/tests.night.luau"
} > "$T/night.luau"
checks=0
fails=0
for name in refill night; do
	out=$("$LUAU" "$(cygpath -w "$T/$name.luau")" 2>&1)
	printf '%s\n' "$out" | grep -E "MESURE|ÉCHEC|ERREUR" || true
	line=$(printf '%s\n' "$out" | grep -E "[0-9]+ vérification\(s\), [0-9]+ échec\(s\)" | tail -1)
	if [ -z "$line" ]; then
		printf '%s\n' "$out" | tail -20
		echo "  $name : arrêté avant la fin"
		fails=$((fails + 1))
		continue
	fi
	c=$(printf '%s' "$line" | grep -oE "[0-9]+ vérification" | grep -oE "[0-9]+")
	f=$(printf '%s' "$line" | grep -oE "[0-9]+ échec" | grep -oE "[0-9]+")
	echo "  $name : $c contrôles, $f raté(s)"
	checks=$((checks + c))
	fails=$((fails + f))
done
echo "$LABEL : $checks vérification(s), $fails échec(s)"
exit $((fails > 0))
