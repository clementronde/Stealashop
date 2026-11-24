#!/usr/bin/env bash
# Banc a157, partie heist (2026-11-14, vague 49, Cantin : en zone safe, plus aucun événement des magasins PNJ).
# Vrais : StoreHeistService, CarryService, GuardService, BatService, WindowService, ToolService, StatsService,
# TruckEventService, Shared (SafeZone compris). Faux Roblox, mise en place et outils du banc a110 (copie a134 :
# a30 copie a66, head103.luau, levier-force, coups-en-rafale), lus sur place. Zone safe du faux monde : x < 25.
#   safe   chrono HEIST masqué à l'arrivée en zone safe (objet en main), jamais montré à un joueur à l'abri près
#          du magasin ; vigile de jour en attente de départ (0,5 s) qui abandonne si sa cible est déjà à l'abri
# « SAUTÉ » sur un arbre sans Shared/SafeZone (avant a157).
#   bash run.sh [racine du dépôt]   VERBOSE=1 : écrit aussi les lignes ok
set -u
H="$(cd "$(dirname "$0")" && pwd)"
A110="$H/../../a134-banc/autres-bancs/a110"
ROOT="${1:-/f/StealAShop}"
shift || true
SRC="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
BASE="$H/../../a66-banc/autres-bancs/a30-banc"
LABEL="banc a157 heist (zone safe)"
if [ ! -f "$SRC/shared/SafeZone.luau" ]; then
	echo "$LABEL : SAUTÉ (pas de Shared/SafeZone) : 0 vérification(s), 0 échec(s)"
	exit 0
fi
FILES="shared server/Services/BatService.luau server/Services/CarryService.luau server/Services/GuardService.luau server/Services/StoreHeistService.luau server/Services/WindowService.luau server/Services/ToolService.luau server/Services/StatsService.luau server/Services/TruckEventService.luau client/Controllers/BatController.luau client/Controllers/HitController.luau client/Controllers/TruckController.luau"
sources() {
	(cd "$SRC" && find $FILES -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
}
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
OUT="$TMP/run.luau"
{
	if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; fi
	cat "$BASE/stubs.luau"
	cat "$BASE/../stub-anticheat.luau"
	sources
	cat "$A110/../../levier-force.luau"
	cat "$A110/../../coups-en-rafale.luau"
	cat "$BASE/setup.luau"
	cat "$A110/head103.luau"
	cat "$H/tests.safe.luau"
} > "$OUT"
out=$("$LUAU" "$(cygpath -w "$OUT")" 2>&1)
line=$(printf '%s\n' "$out" | grep -E "^scénario .* : [0-9]+ vérification\(s\), [0-9]+ échec\(s\)$" | tail -1)
if [ -z "$line" ]; then
	printf '%s\n' "$out" | tail -25
	echo "$LABEL : arrêté avant la fin (erreur ci-dessus) : 0 vérification(s), 1 échec(s)"
	exit 1
fi
if [ "${VERBOSE:-}" = "1" ]; then printf '%s\n' "$out"; else printf '%s\n' "$out" | grep -E "ÉCHEC|ERREUR|^    " || true; fi
c=$(printf '%s' "$line" | sed -E 's/.* : ([0-9]+) vérification.*/\1/')
f=$(printf '%s' "$line" | sed -E 's/.*, ([0-9]+) échec.*/\1/')
echo "$LABEL : $c vérification(s), $f échec(s)"
exit $((f > 0))
