#!/usr/bin/env bash
# Banc hors Studio d'a192 (2026-11-15, vague 59, L-184 points 1 à 4, L-182 point 9) : capture mise en scène, alerte en
# deux paliers, HUD masqué en poursuite, carte « ITEM SECURED! ».
#   server  remote CatchScene de GuardService (vrai GuardService, mise en place du banc a174 : a66-banc/autres-bancs/
#           a30-banc et a114-banc/autres-bancs/a103-banc/head.luau) : rue (« Drop »), magasin de l'objet (« Shelf »),
#           envoyé au coup, au seul joueur attrapé, une fois ; joueur parti.
#   client  CatchSceneController, ChaseController (HeistHint), ChaseFeelController (HUD masqué, Highlight),
#           Controllers/UI/HudMask (mise en place du banc a68 : a71-banc/autres-bancs/a42-banc et a68-banc), HeistController
#           bouchonné.
# Les billets qui volent (GainController) sont dans la copie du banc a60 : autres-bancs/a60 (scénario gains).
# Arbre sans a192 (pas de Config/HeistFeel) : « SAUTÉ ».
#   bash run.sh [racine du dépôt] [scénarios…]   VERBOSE=1 : sortie complète
set -u
H="$(cd "$(dirname "$0")" && pwd)"
N="$(cd "$H/.." && pwd)"
ROOT="${1:-/f/StealAShop}"
ROOT="${ROOT%/src}"
shift || true
SRC="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
LABEL="banc a192 (capture, alerte, HUD masqué, carte)"
if [ ! -f "$SRC/shared/Config/HeistFeel.luau" ]; then
	echo "$LABEL : SAUTÉ, a192 pas encore fusionné : 0 vérification(s), 0 échec(s)"
	exit 0
fi
SCENARIOS="${*:-server client}"
sources() {
	(cd "$SRC" && find $1 -name '*.luau' 2>/dev/null | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
}
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
total_checks=0
total_fails=0
for name in $SCENARIOS; do
	OUT="$TMP/run.$name.luau"
	if [ "$name" = "server" ]; then
		BASE="$N/a66-banc/autres-bancs/a30-banc"
		FILES="shared server/Services/BatService.luau server/Services/CarryService.luau server/Services/GuardService.luau server/Services/StoreHeistService.luau server/Services/WindowService.luau server/Services/ToolService.luau server/Services/StatsService.luau server/Services/TruckEventService.luau client/Controllers/BatController.luau client/Controllers/HitController.luau client/Controllers/TruckController.luau"
		{
			if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; fi
			cat "$BASE/stubs.luau"
			cat "$BASE/../stub-anticheat.luau"
			sources "$FILES"
			cat "$N/a134-banc/levier-force.luau" "$N/a134-banc/coups-en-rafale.luau"
			cat "$BASE/setup.luau"
			cat "$N/a114-banc/autres-bancs/a103-banc/head.luau"
			cat "$H/tests.server.luau"
		} > "$OUT"
	elif [ "$name" = "client" ]; then
		A68="$N/a71-banc/autres-bancs/a68-banc"
		FILES="shared client/Controllers/UI client/Controllers/ChaseFeelController.luau client/Controllers/ChaseController.luau client/Controllers/MusicController.luau client/Controllers/CatchSceneController.luau client/Controllers/NotifyController.luau client/Controllers/ZoneGateController.luau client/Controllers/StoreInfoController.luau client/Controllers/TruckController.luau server/Services/WindowService.luau server/Services/CarryService.luau server/Services/TruckEventService.luau server/Services/ContractChecker.luau"
		{
			if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; fi
			cat "$A68/stubs.luau"
			sources "$FILES"
			cat "$H/pre.client.luau"
			cat "$N/a71-banc/autres-bancs/a42-banc/setup.luau"
			cat "$A68/common.luau"
			cat "$H/head.client.luau"
			cat "$H/tests.client.luau"
		} > "$OUT"
	else
		echo "scénario inconnu : $name"
		total_fails=$((total_fails + 1))
		continue
	fi
	out=$("$LUAU" "$(cygpath -w "$OUT")" 2>&1)
	line=$(printf '%s\n' "$out" | grep -E "^scénario .* : [0-9]+ vérification\(s\), [0-9]+ échec\(s\)$" | tail -1)
	if [ -z "$line" ]; then
		printf '%s\n' "$out" | tail -25
		echo "scénario $name : arrêté avant la fin (erreur ci-dessus)"
		total_fails=$((total_fails + 1))
		continue
	fi
	if [ "${VERBOSE:-}" = "1" ]; then printf '%s\n' "$out"; else printf '%s\n' "$out" | grep -E "ÉCHEC|ERREUR" || true; fi
	c=$(printf '%s' "$line" | sed -E 's/.* : ([0-9]+) vérification.*/\1/')
	f=$(printf '%s' "$line" | sed -E 's/.*, ([0-9]+) échec.*/\1/')
	echo "  $name : $c contrôles, $f raté(s)"
	total_checks=$((total_checks + c))
	total_fails=$((total_fails + f))
done
echo "$LABEL : $total_checks vérification(s), $total_fails échec(s)"
exit $((total_fails > 0))
