#!/usr/bin/env bash
# Copie a115 (2026-11-13) : partie server sur la copie a115 du banc a58 (Shared/TrainingZone, TrainLeave).
# Banc hors Studio d'a77 (vague 25, 2026-11-11, retours du Play de Cantin) :
#   1. bar : BenchBarController, toute l'haltère Barbell (Bar, Plate_*, Collar_*) suit les mains à sa place
#      relative à Bar (un BulkMoveTo par image), revient exactement à la fin ; sans Barbell, Bar seule.
#      Faux Roblox du banc a72 (a72-banc/bar/harness.luau, BulkMoveTo ajouté par a77).
#   2. server : TrainingService ancre et coupe les collisions de toute l'haltère, rend tout à la fin.
#      Faux Roblox de la copie a72 du banc a58.
#   3. hover : Motion.Button / HoverCard, survol accepté seulement pour l'élément du dessus
#      (GetGuiObjectsAtPosition) ; faux Roblox de la copie a62 du banc a60.
# Sur un arbre sans BARBELL dans BenchBarController : SAUTÉ.
#   bash run.sh [racine du dépôt]   (défaut : /f/StealAShop)
set -u
H="$(cd "$(dirname "$0")" && pwd)"
N="$(cd "$H/../../.." && pwd)"
ROOT="${1:-/f/StealAShop}"
SRC="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
if ! grep -q "BARBELL" "$SRC/client/Controllers/BenchBarController.luau" 2>/dev/null; then
	echo "banc a77 (haltère, survol) : SAUTÉ, pas de Barbell dans BenchBarController (a77 pas encore fusionné) : 0 vérification(s), 0 échec(s)"
	exit 0
fi
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
total_c=0
total_f=0
run() { # nom fichier motif
	local out line c f
	out=$("$LUAU" "$(cygpath -w "$2")" 2>&1)
	line=$(printf '%s\n' "$out" | grep -E "$3" | tail -1)
	if [ -z "$line" ]; then
		printf '%s\n' "$out" | tail -25
		echo "  $1 : arrêté avant la fin"
		total_f=$((total_f + 1))
		return
	fi
	if [ "${VERBOSE:-}" = "1" ]; then printf '%s\n' "$out"; else printf '%s\n' "$out" | grep -E "ÉCHEC|ERREUR" || true; fi
	c=$(printf '%s' "$line" | sed -E 's/.* ([0-9]+) vérification.*/\1/; s/^([0-9]+) vérification.*/\1/')
	f=$(printf '%s' "$line" | sed -E 's/.*, ([0-9]+) échec.*/\1/')
	echo "  $1 : $c contrôles, $f raté(s)"
	total_c=$((total_c + c))
	total_f=$((total_f + f))
}
# 1. bar
{
	if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; else echo "VERBOSE = false"; fi
	printf 'SOURCE = [==========[\n'
	tr -d '\r' < "$SRC/client/Controllers/BenchBarController.luau"
	printf '\n]==========]\n'
	cat "$N/a72-banc/bar/harness.luau" "$H/tests.bar.luau"
} > "$TMP/bar.luau"
run bar "$TMP/bar.luau" "^banc a77 \(haltère\) : [0-9]+ vérification"
# 2. server
A58="$N/a115-banc/autres-bancs/a58-banc"
FILES="server/Services/TrainingService.luau shared/TrainingZone.luau shared/Config/Training.luau shared/Config/DeepFreeze.luau shared/Net/RateLimiter.luau"
{
	if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; else echo "VERBOSE = false"; fi
	echo "SOURCES = {}"
	printf '%s\n' $FILES | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
	cat "$A58/harness.luau" "$H/tests.server.luau"
} > "$TMP/server.luau"
run server "$TMP/server.luau" "^banc a77 \(haltère, serveur\) : [0-9]+ vérification"
# 3. hover
B="$N/a62-banc/autres-bancs/a60-banc"
UIFILES="shared client/Controllers/UI client/Controllers/HudController.luau client/Controllers/GainController.luau client/Controllers/UiFeelController.luau"
{
	cat "$B/stubs.luau" "$B/ext-motion.luau" "$B/ext-a60.luau"
	(cd "$SRC" && find $UIFILES -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
	cat "$B/setup.luau" "$B/setup-a60.luau" "$H/tests.hover.luau"
} > "$TMP/hover.luau"
run hover "$TMP/hover.luau" "^[0-9]+ vérification\(s\), [0-9]+ échec\(s\)$"
echo "banc a77 (haltère, survol) : $total_c vérification(s), $total_f échec(s)"
exit $((total_f > 0))
