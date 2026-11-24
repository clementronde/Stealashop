#!/usr/bin/env bash
# Banc hors Studio d'a421 (24/11, Cantin, liaison L-316) : pendant la cinématique d'ouverture d'un colis du rayon, plus
# de contour ni d'invite « Open » à son ancienne place ; le serveur refuse un 2e appui ; tout revient à la fin.
#   server  StoreHeistService (mise en place du banc a202 ; étapes Begin/End écrites, maintien = temps de prise de la
#           rareté du colis) : colis marqué RevealId pendant la cinématique, 2e appui de l'ouvreur et d'un autre joueur
#           refusé, marque retirée à la fin (RevealDone, mort)
#   heist   vrai HeistController sur le faux Roblox du banc a104 (+ PromptButtonHoldEnded, comme a265) : invite coupée sur
#           un colis marqué RevealId (même après le délai d'1 s de l'appui), toutes coupées pour un ouvreur
#           RevealProtected, rendues à la fin et sur un colis neuf
#   unbox   RevealController + Reveal/Unbox (mise en place du banc client a257) : contour Highlight, arêtes SelectionBox,
#           étiquette, décalque et tout contour ajouté pendant la scène éteints dès le début, remis à la fin
#   bash run.sh [racine du dépôt] [scénarios…]   VERBOSE=1 : sortie complète
set -u
H="$(cd "$(dirname "$0")" && pwd)"
N="$(cd "$H/.." && pwd)"
ROOT="${1:-/f/StealAShop}"
ROOT="${ROOT%/src}"
shift || true
SRC="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
LABEL="banc a421 (contour et invite pendant l'ouverture, L-316)"
if [ ! -f "$SRC/client/Controllers/Reveal/Unbox.luau" ]; then
	echo "$LABEL : SAUTÉ, pas de Reveal/Unbox : 0 vérification(s), 0 échec(s)"
	exit 0
fi
SCENARIOS="${*:-server heist unbox}"
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
A104="$N/a104-banc"
CLIENT_FILES="shared client/Controllers/UI client/Controllers/Reveal client/Controllers/RevealController.luau"
SERVER_FILES="shared server/Services/BatService.luau server/Services/CarryService.luau server/Services/GuardService.luau server/Services/StoreHeistService.luau server/Services/WindowService.luau server/Services/ToolService.luau server/Services/StatsService.luau server/Services/TruckEventService.luau client/Controllers/BatController.luau client/Controllers/HitController.luau client/Controllers/TruckController.luau"
for name in $SCENARIOS; do
	OUT="$TMP/run.$name.luau"
	case "$name" in
	unbox)
		{
			if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; fi
			cat "$A68/stubs.luau"
			sources "$CLIENT_FILES"
			cat "$A204/pre.client.luau"
			cat "$N/a71-banc/autres-bancs/a42-banc/setup.luau"
			cat "$A68/common.luau"
			cat "$A204/head.client.luau"
			cat "$N/a257-banc/head.client.luau"
			cat "$H/tests.unbox.luau"
		} > "$OUT"
		;;
	server)
		{
			if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; fi
			cat "$BASE202/stubs.luau"
			cat "$BASE202/../stub-anticheat.luau"
			sources "$SERVER_FILES"
			cat "$A134/levier-force.luau"
			cat "$A134/coups-en-rafale.luau"
			cat "$A202/pre.luau"
			cat "$BASE202/setup.luau"
			cat "$HEAD202"
			cat "$A202/head.luau"
			cat "$H/tests.server.luau"
		} > "$OUT"
		# Comme fusion56 : la doublure d'ItemWeight du banc a202 s'appuie sur le vrai module.
		sed -E -i -f "$N/f56-banc/patches/a202.sed" "$OUT"
		;;
	heist)
		{
			if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; else echo "VERBOSE = false"; fi
			echo "SHELF_OPEN = true"
			echo "SOURCES = {}"
			sources "shared client/Controllers/HeistController.luau"
			# a265 : le faux ProximityPrompt d'a104 n'a pas PromptButtonHoldEnded (HeistController s'y abonne).
			tr -d '\r' < "$A104/harness.luau" | sed 's/PromptButtonHoldBegan = true,/PromptButtonHoldBegan = true, PromptButtonHoldEnded = true,/'
			echo "local function __tests()"
			tr -d '\r' < "$H/tests.heist.luau"
			echo "end"
			echo "local ok, err = pcall(__tests)"
			echo "if not ok then print('  ERREUR ' .. tostring(err)); FAILS += 1 end"
			echo "finish('scénario heist')"
		} > "$OUT"
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
	if [ "${VERBOSE:-}" = "1" ]; then printf '%s\n' "$out"; else printf '%s\n' "$out" | grep -E "ÉCHEC|ERREUR" || true; fi
	c=$(printf '%s' "$line" | sed -E 's/.* : ([0-9]+) vérification.*/\1/')
	f=$(printf '%s' "$line" | sed -E 's/.*, ([0-9]+) échec.*/\1/')
	echo "  $name : $c contrôles, $f raté(s)"
	total_checks=$((total_checks + c))
	total_fails=$((total_fails + f))
done
echo "$LABEL : $total_checks vérification(s), $total_fails échec(s)"
exit $((total_fails > 0))
