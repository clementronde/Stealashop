#!/usr/bin/env bash
# Banc hors Studio d’a259 (vague 75, L-261, L-262, T-222) : copie du banc a257 complétée (sons de l’ouverture, cote réelle,
# fondu de la caméra à l’entrée, caméra jamais rendue en Scriptable). a257 (vague 74, L-253, L-254, L-255, L-258) : copie du banc a251.
#   plan       Shared/UnboxPlan : nombre d’actions selon le résultat, améliorations tirées à part, rareté montrée qui part
#              du colis, places (gauche, droite, sur le colis), téléportations, durées ; DUREES=1 : durées par rareté
#   client     RevealController + Reveal/Unbox (mise en place du banc a204), sans les mots ; places et téléportations,
#              Stomp et Slam, caméra, glissement du billboard, base du champ de vision publiée pour UiFeel
#   server     StoreHeistService (mise en place du banc a202) : plan, plafond du plan tiré
#   serveroff  Config/Unbox.New.Enabled = false : ni plan, ni nouveau plafond
#   serverrange Config/Unbox.New.RealOdds = false : cote finale dans la plage de la rareté (a259)
# Lancé sous f70c4-banc/corrige.sh (Config/Reveal.Return.Time = 0, comme le banc a251). Arbre sans a259 : le banc a257.
#   bash run.sh [racine du dépôt] [scénarios…]   VERBOSE=1 : sortie complète
# Arbre sans a259 : le banc d'avant (a257), avant tout emballage.
R0="${1:-/f/StealAShop}"
if ! grep -q "RealOdds" "${R0%/src}/src/shared/Config/Unbox.luau" 2>/dev/null; then
	exec bash "$(cd "$(dirname "$0")/.." && pwd)/a257-banc/run.sh" "$@"
fi
if [ -z "${A259_CORRIGE:-}" ]; then
	A259_CORRIGE=1 exec bash "$(cd "$(dirname "$0")/.." && pwd)/f70c4-banc/corrige.sh" a251 bash "$0" "$@"
fi
set -u
H="$(cd "$(dirname "$0")" && pwd)"
N="$(cd "$H/.." && pwd)"
ROOT="${1:-/f/StealAShop}"
ROOT="${ROOT%/src}"
shift || true
SRC="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
LABEL="banc a259 (ouverture du colis : sons, cote réelle, caméra)"
SCENARIOS="${*:-plan client server serveroff serverrange}"
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
	server | serveroff | serverrange)
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
