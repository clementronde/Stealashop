#!/usr/bin/env bash
# Banc hors Studio d'a158 (vague 50, 2026-11-14, décision de Cantin : le colis porté n'existe plus).
#   carry   : CarryService sans NPCBox (payload refusé, PlaceDrop retiré), objet NPCItem porté, tombé, lâché, ramassé,
#             expiré ; objet volé inchangé ; AttachBoxLabel gardé. Faux Roblox : fake.luau du banc a17-carry (copie a128).
#   base    : UnboxService sans colis (PlaceBox et OpenBox d'un uid de Boxes refusés, GiveBox retiré, accroches inertes),
#             objet NPCItem ramené = antivol au sol comme avant ; DataService.convertBoxes sans condition ; GiveBox admin
#             = un objet. Chaîne de bouchons du banc a105 (copie a154).
#   pvp     : dépôt d'un objet volé (PvPService) : remote ItemSecured(itemId) au voleur, une fois. Chaîne du banc a152.
#   bash run.sh [racine du dépôt] [scénarios…]   (défaut : /f/StealAShop)   VERBOSE=1 : sortie complète
set -u
H="$(cd "$(dirname "$0")" && pwd)"
N="$(cd "$H/.." && pwd)"
ROOT="${1:-/f/StealAShop}"
shift || true
SRC="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
SCENARIOS="${*:-carry base pvp}"
if grep -q "NPCBoxPayload = {" "$SRC/shared/Types/Carry.luau" 2>/dev/null; then
	echo "banc a158 (fin du colis porté) : SAUTÉ, a158 pas encore fusionné : 0 vérification(s), 0 échec(s)"
	exit 0
fi
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
sources() { # $1 = fichiers ou dossiers, relatifs à src
	(cd "$SRC" && find $1 -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
}
A105="$N/a154-banc/autres-bancs/a105"
FILES105="shared client/Controllers/UI server/Services/InventoryService.luau server/Services/IndexService.luau server/Services/MonetizationService.luau server/Services/DataService.luau server/Services/DisplayService.luau server/Services/PlotService.luau server/Services/TrainingService.luau server/Services/UnboxService.luau server/Services/StatsService.luau server/Services/ToolService.luau server/Services/ShopService.luau server/Services/HotbarService.luau server/Services/PvPService.luau server/Services/HeldItemService.luau client/Controllers/UnboxController.luau client/Controllers/InventoryController.luau client/Controllers/HotbarController.luau client/Controllers/DisplayController.luau client/Controllers/Unbox"
A152="$N/a152-banc"
A142="$N/a142-banc"
A118="$N/a118-banc"
A76="$N/a76-banc"
A74="$A76/autres-bancs/a74-banc"
A61="$N/a62-banc/autres-bancs/a61-banc"
B51="$A61/autres-bancs/a51-banc"
B53="$A61/autres-bancs/a53-banc"
total_checks=0
total_fails=0
for name in $SCENARIOS; do
	OUT="$TMP/run.$name.luau"
	case "$name" in
	carry)
		{
			cat "$N/a128-banc/autres-bancs/a17-carry/fake.luau"
			sources "shared server/Services client"
			cat "$H/carry.ext.luau" "$H/carry.head.luau" "$H/tests.carry.luau"
		} > "$OUT"
		;;
	base)
		{
			if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; fi
			cat "$A105/stubs.luau" "$A105/ext29.luau" "$A105/ext38.luau" "$A105/ext46.luau" "$A105/stub-anticheat.luau" "$A105/ext51.luau"
			sources "$FILES105"
			cat "$A105/features.luau" "$A105/pre.on.luau" "$A105/setup.luau" "$A105/ext105.luau" "$H/tests.base.luau"
		} > "$OUT"
		;;
	pvp)
		{
			if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; fi
			cat "$B51/stubs.luau" "$B51/ext29.luau" "$B51/ext38.luau" "$B51/ext46.luau" "$B51/stub-anticheat.luau" "$B51/ext51.luau" "$B53/ext53.luau" "$A61/ext61.luau" "$A74/ext74.luau" "$A76/ext76.luau" "$A118/ext118.luau"
			sources "$FILES105"
			cat "$B51/features.luau" "$B51/pre.on.luau" "$B51/setup.luau" "$A61/setup61.luau" "$A74/setup74.luau" "$A76/setup76.luau" "$N/a105-banc/ext105.luau" "$A142/setup142.luau" "$A152/setup152.luau" "$A152/steal152.luau" "$H/tests.pvp.luau"
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
echo "banc a158 (fin du colis porté) : $total_checks vérification(s), $total_fails échec(s)"
exit $((total_fails > 0))
