#!/usr/bin/env bash
# Banc hors Studio d'a251 (vague 73, L-236, L-237, L-246) : la nouvelle ouverture du colis.
#   plan       Shared/UnboxPlan : tirage, relecture, cote, durées (sans Roblox)
#   client     RevealController + Reveal/Unbox, mise en place du banc a204 (a246-banc/autres-bancs/a204) : repli codé,
#              animations et marqueurs, outils, effets, silhouettes, révélation, fin, spectateur, mur devant la caméra,
#              plan illisible, fin avant l'heure
#   server     StoreHeistService (mise en place du banc a202) : plan envoyé dans RevealStarted, plafond de la phase
#   serveroff  Config/Unbox.New.Enabled = false : ni plan, ni nouveau plafond
# Arbre sans a251 (pas de Shared/UnboxPlan) : « SAUTÉ ».
#   bash run.sh [racine du dépôt] [scénarios…]   VERBOSE=1 : sortie complète ; DUREES=1 : durées par rareté (scénario plan)
set -u
H="$(cd "$(dirname "$0")" && pwd)"
N="$(cd "$H/.." && pwd)"
ROOT="${1:-/f/StealAShop}"
ROOT="${ROOT%/src}"
shift || true
SRC="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
LABEL="banc a251 (nouvelle ouverture du colis)"
if [ ! -f "$SRC/shared/UnboxPlan.luau" ]; then
	echo "$LABEL : SAUTÉ, a251 pas encore fusionné : 0 vérification(s), 0 échec(s)"
	exit 0
fi
SCENARIOS="${*:-plan client server serveroff}"
sources() {
	(cd "$SRC" && find $1 -name '*.luau' 2>/dev/null | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
}
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
total_checks=0
total_fails=0
A68="$N/a71-banc/autres-bancs/a68-banc"
A204="$N/a246-banc/autres-bancs/a204"
A202="$N/a202-banc"
BASE202="$N/a66-banc/autres-bancs/a30-banc"
HEAD202="$N/a114-banc/autres-bancs/a103-banc/head.luau"
A134="$N/a134-banc"
CLIENT_FILES="shared client/Controllers/UI client/Controllers/Reveal client/Controllers/RevealController.luau"
SERVER_FILES="shared server/Services/BatService.luau server/Services/CarryService.luau server/Services/GuardService.luau server/Services/StoreHeistService.luau server/Services/WindowService.luau server/Services/ToolService.luau server/Services/StatsService.luau server/Services/TruckEventService.luau client/Controllers/BatController.luau client/Controllers/HitController.luau client/Controllers/TruckController.luau"
for name in $SCENARIOS; do
	OUT="$TMP/run.$name.luau"
	case "$name" in
	plan | client)
		{
			if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; fi
			cat "$A68/stubs.luau"
			sources "$CLIENT_FILES"
			cat "$A204/pre.client.luau"
			cat "$N/a71-banc/autres-bancs/a42-banc/setup.luau"
			cat "$A68/common.luau"
			cat "$A204/head.client.luau"
			cat "$H/head.client.luau"
			cat "$H/tests.$name.luau"
		} > "$OUT"
		;;
	server | serveroff)
		{
			if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; fi
			cat "$BASE202/stubs.luau"
			cat "$BASE202/../stub-anticheat.luau"
			sources "$SERVER_FILES"
			cat "$A134/levier-force.luau"
			cat "$A134/coups-en-rafale.luau"
			cat "$A202/pre.luau"
			if [ -f "$H/pre.$name.luau" ]; then cat "$H/pre.$name.luau"; fi
			cat "$BASE202/setup.luau"
			cat "$HEAD202"
			cat "$A202/head.luau"
			cat "$H/tests.$name.luau"
		} > "$OUT"
		# Comme fusion56 : la doublure d'ItemWeight du banc a202 s'appuie sur le vrai module.
		sed -E -i -f "$N/f56-banc/patches/a202.sed" "$OUT"
		;;
	*)
		echo "scénario inconnu : $name"
		total_fails=$((total_fails + 1))
		continue
		;;
	esac
	out=$("$LUAU" "$(cygpath -w "$OUT")" 2>&1)
	line=$(printf '%s\n' "$out" | grep -E "^scénario .* : [0-9]+ vérification\(s\), [0-9]+ échec\(s\)$" | tail -1)
	if [ -z "$line" ]; then
		printf '%s\n' "$out" | tail -25
		echo "scénario $name : arrêté avant la fin (erreur ci-dessus)"
		total_fails=$((total_fails + 1))
		continue
	fi
	if [ "${VERBOSE:-}" = "1" ]; then printf '%s\n' "$out"; else printf '%s\n' "$out" | grep -E "ÉCHEC|ERREUR${DUREES:+|^DUREES}" || true; fi
	c=$(printf '%s' "$line" | sed -E 's/.* : ([0-9]+) vérification.*/\1/')
	f=$(printf '%s' "$line" | sed -E 's/.*, ([0-9]+) échec.*/\1/')
	echo "  $name : $c contrôles, $f raté(s)"
	total_checks=$((total_checks + c))
	total_fails=$((total_fails + f))
done
echo "$LABEL : $total_checks vérification(s), $total_fails échec(s)"
exit $((total_fails > 0))
