#!/usr/bin/env bash
# Banc hors Studio d a244 (vague 72, L-216 point 5 et L-231 : renaissance allumée au lancement, Features.Rebirth = true).
# Scénarios (tests.luau, sur lib.luau : copie a244 de celle d a164) : on (vrai RebirthService hors Studio : allumé,
# remote, réserve vidée, double demande ignorée), alert (vrai RailAlertController : pastille RebirthAlert).
# Arbre sans Rebirth = true dans Config/Features : SAUTÉ.
#   bash run.sh [racine du dépôt] [scénarios…]   (défaut : /f/StealAShop)
set -u
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop}"
ROOT="${ROOT%/src}"
shift || true
SRC="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
SCENARIOS="${*:-on alert}"
if ! grep -q "^	Rebirth = true," "$SRC/shared/Config/Features.luau" 2>/dev/null; then
	echo "banc a244 (renaissance au lancement) : SAUTÉ, Features.Rebirth n est pas à true dans $SRC : 0 vérification(s), 0 échec(s)"
	exit 0
fi
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
COMMON="$TMP/common.luau"
(cd "$SRC" && awk '
	FNR == 1 { if (key != "") printf "]==========]\n"; key = FILENAME; sub(/\.luau$/, "", key); sub(/^shared\//, "", key); sub(/^server\/Services\//, "", key); sub(/^client\/Controllers\//, "", key); printf "SOURCES[\"%s\"] = [==========[\n", key }
	{ sub(/\r$/, ""); print }
	END { printf "]==========]\n" }
' shared/Config/*.luau shared/*.luau shared/Contract/Find.luau shared/Types/Profile.luau server/Services/RebirthService.luau client/Controllers/RailAlertController.luau) > "$COMMON"
tr -d '\r' < "$H/lib.luau" >> "$COMMON"
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
echo "banc a244 (renaissance au lancement) : $total_checks vérification(s), $total_fails échec(s)"
exit $((total_fails > 0))
