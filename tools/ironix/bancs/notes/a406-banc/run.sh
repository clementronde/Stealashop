#!/usr/bin/env bash
# Banc hors Studio d'a406 (vague GC4, 2026-11-23, L-297 : construction « en mode Lego » de la boutique) :
#   plan  Shared/ShopBuildPlan (courbe Back, ordre du bas vers le haut, plafond des grosses pièces, écart réduit
#         pour tenir la durée max, hauteur des clics, achat reconnu, numéros des présentoirs), Config/ShopBuild
#         (repli = valeurs de L-297), Contract/Models (fiche FX_ShopUpgrade_Build facultative) ; vrais modules de
#         src/shared avec le chargeur du banc a262.
# Arbre sans a406 : « SAUTÉ ».
#   bash run.sh [racine du dépôt]   VERBOSE=1 : lignes ok
set -u
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop}"
ROOT="${ROOT%/src}"
SRC="$ROOT/src"
LABEL="banc a406 (construction de la boutique en mode Lego)"
if [ ! -f "$SRC/shared/ShopBuildPlan.luau" ]; then
	echo "$LABEL : SAUTÉ, a406 pas encore fusionné : 0 vérification(s), 0 échec(s)"
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
line=$(printf '%s\n' "$out" | grep -E "plan : [0-9]+ vérification" | tail -1)
total=0; failed=0
if [ -z "$line" ]; then failed=1; else
	total=$(printf '%s' "$line" | sed -E 's/.* : ([0-9]+) vérif.*/\1/')
	failed=$(printf '%s' "$line" | sed -E 's/.*, ([0-9]+) échec.*/\1/')
fi
echo "$LABEL : $total vérification(s), $failed échec(s)"
exit $((failed > 0))
