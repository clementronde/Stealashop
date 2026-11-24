#!/usr/bin/env bash
# Banc hors Studio d'a174 (2026-11-15, vague 54, retours de Cantin du 15/11) :
#   capture (tests.capture.luau, mise en place du banc a114 : a66-banc/autres-bancs/a30-banc et
#            a114-banc/autres-bancs/a103-banc/head.luau) : 3e capture d'un même objet par deux porteurs -> retour au
#            rayon tel quel, en vol ; repris : compteur neuf ; 2 captures puis rangé en zone safe : gardé.
#   copies : autres-bancs/a173 et autres-bancs/a168 (poursuite à 14 studs, ruée +30 %, nuit et police vers 2,5 s),
#            autres-bancs/a114 (retour à la 3e capture coupé), lancées par le lanceur commun.
# Arbre sans a174 (pas de ReturnToShelfAfterCatches dans Config/Chase) : « SAUTÉ ».
#   bash run.sh [racine du dépôt]   VERBOSE=1 : lignes ok et sortie
set -u
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop}"
ROOT="${ROOT%/src}"
SRC="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
LABEL="banc a174 (3e capture du même objet)"
if ! grep -q "ReturnToShelfAfterCatches" "$SRC/shared/Config/Chase.luau" 2>/dev/null; then
	echo "$LABEL : SAUTÉ, a174 pas encore fusionné : 0 vérification(s), 0 échec(s)"
	exit 0
fi
BASE="$H/../a66-banc/autres-bancs/a30-banc"
HEAD="$H/../a114-banc/autres-bancs/a103-banc/head.luau"
A134="$H/../a134-banc"
FILES="shared server/Services/BatService.luau server/Services/CarryService.luau server/Services/GuardService.luau server/Services/StoreHeistService.luau server/Services/WindowService.luau server/Services/ToolService.luau server/Services/StatsService.luau server/Services/TruckEventService.luau client/Controllers/BatController.luau client/Controllers/HitController.luau client/Controllers/TruckController.luau"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
OUT="$TMP/run.capture.luau"
{
	if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; fi
	cat "$BASE/stubs.luau"
	cat "$BASE/../stub-anticheat.luau"
	(cd "$SRC" && find $FILES -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
	cat "$A134/levier-force.luau"
	cat "$A134/coups-en-rafale.luau"
	cat "$BASE/setup.luau"
	cat "$HEAD"
	cat "$H/tests.capture.luau"
} > "$OUT"
out=$("$LUAU" "$(cygpath -w "$OUT")" 2>&1)
line=$(printf '%s\n' "$out" | grep -E "^scénario .* : [0-9]+ vérification\(s\), [0-9]+ échec\(s\)$" | tail -1)
if [ -z "$line" ]; then
	printf '%s\n' "$out" | tail -25
	echo "$LABEL : 0 vérification(s), 1 échec(s)"
	exit 1
fi
if [ "${VERBOSE:-}" = "1" ]; then printf '%s\n' "$out"; else printf '%s\n' "$out" | grep -E "ÉCHEC|ERREUR" || true; fi
c=$(printf '%s' "$line" | sed -E 's/.* : ([0-9]+) vérification.*/\1/')
f=$(printf '%s' "$line" | sed -E 's/.*, ([0-9]+) échec.*/\1/')
echo "$LABEL : $c vérification(s), $f échec(s)"
exit $((f > 0))
