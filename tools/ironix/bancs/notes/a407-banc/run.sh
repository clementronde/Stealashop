#!/usr/bin/env bash
# Banc hors Studio d a407 (vague GC6, 23/11, MAJ 3 : outils de renaissance, Features.RebirthTools).
# Scénarios (tests.luau, sur la lib.luau d a244 lue à sa place) : config (Config/Tools, Config/Rebirths.RewardText),
# off (interrupteur coupé : pas d outil de renaissance), keep (vrai RebirthService : outils gardés et remis en main),
# door (vrai ToolService.GetDoorHits), shop (vrai ShopService : achat fermé avant la renaissance demandée).
# Arbre sans Features.RebirthTools : SAUTÉ.
#   bash run.sh [racine du dépôt] [scénarios…]   (défaut : /f/StealAShop)
set -u
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop}"
ROOT="${ROOT%/src}"
shift || true
SRC="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
SCENARIOS="${*:-config off keep door shop}"
if ! grep -q "RebirthTools = " "$SRC/shared/Config/Features.luau" 2>/dev/null; then
	echo "banc a407 (outils de renaissance) : SAUTÉ, pas de Features.RebirthTools dans $SRC : 0 vérification(s), 0 échec(s)"
	exit 0
fi
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
COMMON="$TMP/common.luau"
(cd "$SRC" && awk '
	FNR == 1 { if (key != "") printf "]==========]\n"; key = FILENAME; sub(/\.luau$/, "", key); sub(/^shared\//, "", key); sub(/^server\/Services\//, "", key); sub(/^client\/Controllers\//, "", key); printf "SOURCES[\"%s\"] = [==========[\n", key }
	{ sub(/\r$/, ""); print }
	END { printf "]==========]\n" }
' shared/Config/*.luau shared/*.luau shared/Contract/Find.luau shared/Types/Profile.luau server/Services/RebirthService.luau server/Services/ToolService.luau server/Services/ShopService.luau) > "$COMMON"
tr -d '\r' < "$H/../a244-banc/lib.luau" >> "$COMMON"
tr -d '\r' < "$H/tests.luau" >> "$COMMON"
total_checks=0
total_fails=0
for name in $SCENARIOS; do
	OUT="$TMP/run.$name.luau"
	{
		echo "--!nocheck"
		echo "SOURCES = {}"
		echo "SCENARIO = \"$name\""
		cat "$COMMON"
	} > "$OUT"
	out=$("$LUAU" "$(cygpath -w "$OUT")" 2>&1)
	line=$(printf '%s\n' "$out" | grep -E "^[0-9]+ vérification\(s\), [0-9]+ échec\(s\)$" | tail -1)
	if [ -z "$line" ]; then
		printf '%s\n' "$out" | tail -25
		echo "scénario $name : arrêté avant la fin (erreur ci-dessus)"
		total_fails=$((total_fails + 1))
		continue
	fi
	if [ "${VERBOSE:-}" = "1" ]; then printf '%s\n' "$out"; else printf '%s\n' "$out" | grep -E "ÉCHEC|ERREUR" || true; fi
	c=$(printf '%s' "$line" | sed -E 's/^([0-9]+) vérification.*/\1/')
	f=$(printf '%s' "$line" | sed -E 's/.*, ([0-9]+) échec.*/\1/')
	echo "  $name : $c contrôles, $f raté(s)"
	total_checks=$((total_checks + c))
	total_fails=$((total_fails + f))
done
echo "banc a407 (outils de renaissance) : $total_checks vérification(s), $total_fails échec(s)"
exit $((total_fails > 0))
