#!/usr/bin/env bash
# Banc hors Studio d'a181 (2026-11-15, vague 56, petits branchements de Clément).
#   hub    : vrai HubController sur le faux d'a160 : LabelColor (L-165), « INVITE A FRIEND » seul (L-169 Q2).
#   anim   : vrai AnimationController sur un faux minimal : HoldItem pour Big, Huge, Colossal (L-162).
#   aura   : banc a20 (copie a149) avec un bloc K21 inséré : Icon = ICON_Trail_<Nom>, repli FX_Trail_<Nom> (L-171).
#   static : HUD Damage et DamageIcon suivent la potion (L-166 Q4), camion NextZoneChance (Q5), record sans boosts
#            (L-168 Q6), Bench hors contrat, ICON_Trail_* reconnues (L-168), halos (L-161) : lectures du code.
# « SAUTÉ » sur un arbre sans a181.
#   bash run.sh [racine du dépôt] [scénarios…]   VERBOSE=1 : sortie complète
set -u
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop}"
shift || true
SRC="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
SCENARIOS="${*:-hub anim aura static}"
NAME="banc a181 (petits branchements de Clément)"
if ! grep -q 'NextZoneChance' "$SRC/shared/Config/TruckEvent.luau" 2>/dev/null; then
	echo "$NAME : SAUTÉ, a181 pas encore fusionné : 0 vérification(s), 0 échec(s)"
	exit 0
fi
A160="$H/../a160-banc"
A20="$H/../a149-banc/autres-bancs/a20"
sources() {
	(cd "$SRC" && find $1 -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
}
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
total_checks=0
total_fails=0
add() { # $1 nom, $2 sortie
	local line c f
	line=$(printf '%s\n' "$2" | grep -E "[0-9]+ vérification\(s\), [0-9]+ échec\(s\)" | tail -1)
	if [ -z "$line" ]; then
		printf '%s\n' "$2" | tail -25
		echo "scénario $1 : arrêté avant la fin (erreur ci-dessus)"
		total_fails=$((total_fails + 1))
		return
	fi
	if [ "${VERBOSE:-}" = "1" ]; then printf '%s\n' "$2"; else printf '%s\n' "$2" | grep -E "ÉCHEC|ERREUR" || true; fi
	c=$(printf '%s' "$line" | sed -E 's/^[^0-9]*([0-9]+) vérification.*/\1/')
	f=$(printf '%s' "$line" | sed -E 's/.*, ([0-9]+) échec.*/\1/')
	echo "  $1 : $c contrôles, $f raté(s)"
	total_checks=$((total_checks + c))
	total_fails=$((total_fails + f))
}
for name in $SCENARIOS; do
	OUT="$TMP/run.$name.luau"
	case "$name" in
	hub | anim)
		{
			echo "SOURCES = {}"
			[ "${VERBOSE:-}" = "1" ] && echo "VERBOSE = true"
			sources "shared/Config/DeepFreeze.luau shared/Config/Hub.luau shared/HubZone.luau shared/Contract/Animations.luau client/Controllers/HubController.luau client/Controllers/AnimationController.luau"
			cat "$A160/fakes.luau" "$H/tests.$name.luau"
		} > "$OUT"
		add "$name" "$("$LUAU" "$(cygpath -w "$OUT")" 2>&1)"
		;;
	aura)
		FILES="shared client/Controllers/UI server/Services/DataService.luau server/Services/StatsService.luau server/Services/ToolService.luau server/Services/CosmeticService.luau client/Controllers/CosmeticController.luau client/Controllers/AuraShopController.luau"
		{
			[ "${VERBOSE:-}" = "1" ] && echo "VERBOSE = true"
			cat "$A20/stubs-a15.luau" "$A20/ext.luau" "$A20/../../../a37-banc/ext-motion.luau"
			sources "$FILES"
			awk -v block="$H/bloc-k21.luau" 'index($0, "== L. ") > 0 && index($0, "print(") == 1 { while ((getline l < block) > 0) print l } { print }' "$A20/tests.luau"
		} > "$OUT"
		out=$("$LUAU" "$(cygpath -w "$OUT")" 2>&1)
		k21=$(printf '%s\n' "$out" | grep -c "K21" || true)
		[ "$k21" -ge 1 ] || out="$out
ÉCHEC K21 : bloc pas exécuté"
		add "$name" "$out"
		;;
	static)
		c=0; f=0
		chk() { c=$((c + 1)); if ! tr -d '\r' < "$SRC/$2" | grep -qF -- "$3"; then f=$((f + 1)); echo "ÉCHEC $1 ($2)"; fi; }
		nochk() { c=$((c + 1)); if tr -d '\r' < "$SRC/$2" | grep -qF -- "$3"; then f=$((f + 1)); echo "ÉCHEC $1 ($2)"; fi; }
		chk S1 client/Controllers/HudController.luau 'label.Visible = strengthPotionOn'
		chk S2 client/Controllers/HudController.luau 'Find.path(current.gui, "DamageIcon")'
		chk S3 shared/Contract/UI.luau 'Path = "DamageIcon", Optional = true'
		chk S4 shared/Config/TruckEvent.luau 'NextZoneChance = 0.1'
		chk S5 server/Services/TruckEventService.luau 'NextZoneChance = TruckEvent.NextZoneChance'
		chk S6 server/Services/StoreHeistService.luau 'if zonesOnly and not Items.AllZones[rarityId] then nil else drawItemNear(zone, rarityId)'
		chk S7 server/Services/StoreHeistService.luau 'NextZoneChance = options.NextZoneChance'
		chk S8 server/Services/LeaderboardService.luau 'return math.max(best, recordIncome(player))'
		nochk S9 shared/Contract/Models.luau '{ Name = "Bench"'
		chk S10 server/Services/ContractChecker.luau 'for _, list in { Cosmetics.Auras, Cosmetics.Trails } do'
		chk S11 shared/Config/TreadmillFX.luau 'WingLight = { Min = 0.6, Max = 1.2'
		chk S12 shared/RarityHalo.luau 'Divine = { LightRange = 18, LightBrightness = 1.2,'
		add static "$c vérification(s), $f échec(s)"
		;;
	esac
done
echo "$NAME : $total_checks vérification(s), $total_fails échec(s)"
exit $((total_fails > 0))
