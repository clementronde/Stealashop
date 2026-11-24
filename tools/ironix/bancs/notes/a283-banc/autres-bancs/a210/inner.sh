#!/usr/bin/env bash
# a218 (vague 66, L-210 point 8) : copie du lanceur du banc a210, Features.NewAuras passe à true dans src/. Deux passages
# comme avant : l arbre tel quel, puis une copie avec la valeur inverse (true <-> false). Tests : ceux d a210 (ils lisent
# la valeur de Features), lus sur place.
# Banc hors Studio d'a210 (vague 63, L-205 et L-206) : pièces WeldTo des auras de Clément (clonées, soudées à la
# bonne place), mouvement Spin, Orbit, Tumble, Period côté client sans fuite, modèle FX_ lu avant le Decal,
# Features.NewAuras (faux : boutique d'aujourd'hui ; vrai : 8 auras et migration).
# Reprend le banc a20 (copie a149) jusqu'à ses scénarios, puis tests.a210.luau. Deux passages : l'arbre tel quel,
# puis une copie de src/ avec NewAuras = true.
# « SAUTÉ » sur un arbre sans CosmeticPiece dans CosmeticController.
#   bash run.sh [racine du dépôt]
set -eu
H="$(cd "$(dirname "$0")/../../../a210-banc" && pwd)"
D283="$(cd "$(dirname "$0")" && pwd)"
A20="$H/../a149-banc/autres-bancs/a20"
A20_OLD="$H/../a37-banc/autres-bancs/a20-banc"
ROOT="${1:-/f/StealAShop/agents/a210}"
if ! grep -q '"CosmeticPiece"' "$ROOT/src/client/Controllers/CosmeticController.luau" 2>/dev/null; then
	echo "banc a210 : SAUTÉ, pas de CosmeticPiece dans CosmeticController (a210 pas encore fusionné) : 0 vérification(s), 0 échec(s)"
	exit 0
fi
TMP="$(mktemp -d)"
trap "rm -rf \"$TMP\"" EXIT; [ -n "${KEEP:-}" ] && trap - EXIT
FILES="shared client/Controllers/UI server/Services/DataService.luau server/Services/StatsService.luau server/Services/ToolService.luau server/Services/CosmeticService.luau client/Controllers/CosmeticController.luau client/Controllers/AuraShopController.luau"
total=0; fails=0; status=0
run_one() { # $1 = dossier src, $2 = libellé
	local SRC="$1" OUT="$TMP/run-$2.luau"
	{
		cat "$A20/stubs-a15.luau" "$A20/ext.luau" "$A20_OLD/../../ext-motion.luau" "$D283/ext283.luau"
		(cd "$SRC" && find $FILES -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
		tr -d '' < "$A20/tests.luau" | awk 'index($0, "== A. Config/Cosmetics") > 0 { exit } { print }'
		tr -d '\r' < "$D283/tests.a210.luau"
		echo "summary()"
	} > "$OUT"
	local W="$OUT"
	if command -v cygpath >/dev/null 2>&1; then W="$(cygpath -w "$OUT")"; fi
	local out line
	out=$("$HOME/.rokit/bin/luau.exe" "$W" 2>&1) || true
	printf '%s\n' "$out" | grep -E "ÉCHEC|ERREUR" | sed "s/^/[$2] /" || true
	if [ "${VERBOSE:-}" = 1 ]; then printf '%s\n' "$out" | tail -40; fi
	line=$(printf '%s\n' "$out" | grep -E "^[0-9]+ vérification\(s\), [0-9]+ échec\(s\)$" | tail -1)
	if [ -z "$line" ]; then printf '%s\n' "$out" | tail -20; echo "[$2] arrêté avant la fin"; fails=$((fails + 1)); status=1; return; fi
	local v e
	v=$(printf '%s' "$line" | sed -E 's/^([0-9]+) .*/\1/'); e=$(printf '%s' "$line" | sed -E 's/.*, ([0-9]+) échec.*/\1/')
	total=$((total + v)); fails=$((fails + e))
	[ "$e" = 0 ] || status=1
}
if grep -q "NewAuras = true" "$ROOT/src/shared/Config/Features.luau"; then FROM=true; TO=false; else FROM=false; TO=true; fi
run_one "$ROOT/src" "NewAuras=$FROM"
mkdir -p "$TMP/new"
cp -r "$ROOT/src" "$TMP/new/src"
F="$TMP/new/src/shared/Config/Features.luau"
grep -q "NewAuras = $FROM" "$F" || { echo "banc a210 : NewAuras = $FROM absent de Features : 0 vérification(s), 1 échec(s)"; exit 1; }
sed -i "s/NewAuras = $FROM/NewAuras = $TO/" "$F"
run_one "$TMP/new/src" "NewAuras=$TO"
echo "banc a210 (pièces WeldTo des auras, NewAuras) : $total vérification(s), $fails échec(s)"
exit $status
