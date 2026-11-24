#!/usr/bin/env bash
# Banc hors Studio d'a263 (vague 77, 2026-11-20) :
#   cote        BB_UnboxOdds : la cote qui défile s'écrit en entiers lisibles (UnboxPlan.oddsText, même arrondi que la
#               cote finale, Formulas.UnboxOdds) ; vrais modules de src/shared avec le chargeur du banc a262.
#   simulateur  tools/ironix/equilibrage (RAPPORT=v2 COURT=1, 3 parties par profil) tourne sur l'arbre et donne les
#               5 temps d'arrivée du joueur moyen.
# (Le maintien d'ouverture vidé après « maintien trop court » : cas H2d de la copie a263 du banc a116.)
# Arbre sans a263 : « SAUTÉ ».
#   bash run.sh [racine du dépôt]   VERBOSE=1 : lignes ok
set -u
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop}"
ROOT="${ROOT%/src}"
SRC="$ROOT/src"
LABEL="banc a263 (maintien, cote entière, simulateur)"
if ! grep -q "a263" "$SRC/shared/UnboxPlan.luau" 2>/dev/null; then
	echo "$LABEL : SAUTÉ, a263 pas encore fusionné : 0 vérification(s), 0 échec(s)"
	exit 0
fi
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
OUT="$TMP/run.luau"
{
	echo "SOURCES = {}"
	echo "VERBOSE = ${VERBOSE:-0} == 1"
	(cd "$SRC/shared" && find . -name '*.luau' | sed 's|^\./||' | sort) | awk -v root="$SRC/shared" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
	cat "$H/../a262-banc/loader.luau"
	cat "$H/tests.luau"
} > "$OUT"
out=$("$HOME/.rokit/bin/luau.exe" "$(cygpath -w "$OUT")" 2>&1)
printf '%s\n' "$out" | grep -v "vérification(s)" || true
line=$(printf '%s\n' "$out" | grep -E "cote : [0-9]+ vérification" | tail -1)
total=0; failed=0
if [ -z "$line" ]; then failed=1; else
	total=$(printf '%s' "$line" | sed -E 's/.* : ([0-9]+) vérif.*/\1/')
	failed=$(printf '%s' "$line" | sed -E 's/.*, ([0-9]+) échec.*/\1/')
fi
# Simulateur d'équilibrage.
sim=$(RAPPORT=v2 COURT=1 GRAINES=3 HEURES=60 bash "$ROOT/tools/ironix/equilibrage/run.sh" "$ROOT" 2>&1)
code=$?
total=$((total + 2))
moyen=$(printf '%s\n' "$sim" | grep -E "^\| Moyen \|" | head -1)
if [ $code -ne 0 ] || printf '%s\n' "$sim" | grep -q "attempt\|stacktrace"; then
	failed=$((failed + 1)); echo "ÉCHEC : S1 le simulateur s'arrête sur une erreur"; printf '%s\n' "$sim" | grep -A3 "attempt" | head -5
elif [ "${VERBOSE:-0}" = "1" ]; then echo "ok : S1 le simulateur tourne"; fi
cells=$(printf '%s' "$moyen" | awk -F'|' '{ n = 0; for (i = 3; i <= 7; i++) if ($i ~ /[0-9]/) n++; print n }')
if [ "${cells:-0}" != "5" ]; then
	failed=$((failed + 1)); echo "ÉCHEC : S2 joueur moyen : arrivée en zones 2 à 6 ($moyen)"
elif [ "${VERBOSE:-0}" = "1" ]; then echo "ok : S2 joueur moyen : $moyen"; fi
echo "$LABEL : $total vérification(s), $failed échec(s)"
exit $((failed > 0))
