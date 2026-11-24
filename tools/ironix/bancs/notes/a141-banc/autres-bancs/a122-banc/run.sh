#!/usr/bin/env bash
# Copie a141 (2026-11-14, L-142) : rendu exposé attendu = celui de main 459c8dd avec les valeurs de Clément (lumière 0,3 à 1,2, portée 4 à 10, Rate / 2, particules et rayons LightEmission 0,3, rayons transparence 0,6) ; le porté ne change pas.
# Banc hors Studio d'a122 (vague 37, 2026-11-14, dettes de code) :
#   halo  : Shared/RarityHalo, seul rendu du halo de rareté (5.6), pose exactement les mêmes instances que
#           l'ancien rendu de CarryService et de DisplayService (ancien-halo.luau, figé de main 2be54ff) pour
#           chaque rareté, porté (8 combinaisons d'effets propres) et exposé (3 tailles) ; faux Roblox à lui
#           (fake.halo.luau), Config/Rarities lu dans le dépôt ;
#   badge : CardAlert et SlotAlert passent par Shared/AlertBadge (allumées, battent sur la même horloge,
#           éteintes), sur le faux Roblox et la mise en place du banc a118, lus sur place.
# Sur un arbre sans Shared/RarityHalo (avant a122) : « SAUTÉ ».
#   bash run.sh [racine du dépôt] [scénarios…]   (défaut : /f/StealAShop ; scénarios : halo badge)
#   VERBOSE=1 bash run.sh                         écrit aussi les lignes ok (et les arbres qui diffèrent)
set -u
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop}"
shift || true
SRC="$ROOT/src"
# Arbre sans les valeurs L-142 (avant a141) : le banc a122 d origine, tel quel (bon avant et après la fusion).
if ! grep -q "SPARKLE_EMISSION" "$SRC/shared/RarityHalo.luau" 2>/dev/null; then exec bash "/c/Users/user/AppData/Local/Claude-Data/claude_pzs8sxrjxfjjc/side-session-notes/local_8069c51a-7fa2-4234-b865-b99cadfc62e3/a122-banc/run.sh" "$ROOT" "$@"; fi
LUAU="$HOME/.rokit/bin/luau.exe"
SCENARIOS="${*:-halo badge}"
if [ ! -f "$SRC/shared/RarityHalo.luau" ]; then
	echo "banc a122 (halo commun, pastilles) : SAUTÉ, a122 pas encore fusionné : 0 vérification(s), 0 échec(s)"
	exit 0
fi
A118="/c/Users/user/AppData/Local/Claude-Data/claude_pzs8sxrjxfjjc/side-session-notes/local_8069c51a-7fa2-4234-b865-b99cadfc62e3/a118-banc"
A76="$A118/../a76-banc"
A74="$A76/autres-bancs/a74-banc"
A61="$A118/../a62-banc/autres-bancs/a61-banc"
B51="$A61/autres-bancs/a51-banc"
B53="$A61/autres-bancs/a53-banc"
A105="$A118/../a105-banc"
FILES="shared client/Controllers/UI server/Services/InventoryService.luau server/Services/IndexService.luau server/Services/MonetizationService.luau server/Services/DataService.luau server/Services/DisplayService.luau server/Services/PlotService.luau server/Services/TrainingService.luau server/Services/UnboxService.luau server/Services/StatsService.luau server/Services/ToolService.luau server/Services/ShopService.luau server/Services/HotbarService.luau server/Services/PvPService.luau client/Controllers/UnboxController.luau client/Controllers/InventoryController.luau client/Controllers/HotbarController.luau client/Controllers/Unbox"
sources() {
	(cd "$SRC" && find $FILES -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
}

total_checks=0
total_fails=0
for name in $SCENARIOS; do
	: "${R1_D:=$(d="${R1_RUN:-${TMPDIR:-/tmp}/r1-bancs}"; mkdir -p "$d" && mktemp -d "$d/b.XXXXXX")}" "${R1_D:?r1 : dossier du banc introuvable}"; OUT="$R1_D/run.$name.luau"
	if [ "$name" = "halo" ]; then
		{
			if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; fi
			cat "$H/fake.halo.luau"
			echo "RARITIES = (function()"
			tr -d '\r' < "$SRC/shared/Config/Rarities.luau" | sed -e 's/require(script\.Parent\.DeepFreeze)/function(x) return x end/' -e 's/^export type/type/'
			echo "end)()"
			echo "NEW_HALO = (function()"
			tr -d '\r' < "$SRC/shared/RarityHalo.luau" | sed -e 's/require(script\.Parent:WaitForChild("Config"):WaitForChild("Rarities"))/RARITIES/' -e 's/^export type/type/'
			echo "end)()"
			cat "$H/ancien-halo.luau"
			cat "$H/tests.halo.luau"
		} > "$OUT"
	else
		{
			if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; fi
			cat "$B51/stubs.luau" "$B51/ext29.luau" "$B51/ext38.luau" "$B51/ext46.luau" "$B51/stub-anticheat.luau" "$B51/ext51.luau" "$B53/ext53.luau" "$A61/ext61.luau" "$A74/ext74.luau" "$A76/ext76.luau" "$A118/ext118.luau"
			sources
			cat "$B51/features.luau" "$B51/pre.on.luau" "$B51/setup.luau" "$A61/setup61.luau" "$A74/setup74.luau" "$A76/setup76.luau" "$A105/ext105.luau" "$A118/setup118.luau" "$H/tests.$name.luau"
		} > "$OUT"
	fi
	out=$("$LUAU" "$(cygpath -w "$OUT")" 2>&1)
	line=$(printf '%s\n' "$out" | grep -E "^scénario .* : [0-9]+ vérification\(s\), [0-9]+ échec\(s\)$" | tail -1)
	if [ -z "$line" ]; then
		printf '%s\n' "$out" | tail -25
		echo "scénario $name : arrêté avant la fin (erreur ci-dessus)"
		total_fails=$((total_fails + 1))
		continue
	fi
	if [ "${VERBOSE:-}" = "1" ]; then
		printf '%s\n' "$out"
	else
		printf '%s\n' "$out" | grep -E "ÉCHEC|ERREUR" || true
	fi
	c=$(printf '%s' "$line" | sed -E 's/.* : ([0-9]+) vérification.*/\1/')
	f=$(printf '%s' "$line" | sed -E 's/.*, ([0-9]+) échec.*/\1/')
	echo "  $name : $c contrôles, $f raté(s)"
	total_checks=$((total_checks + c))
	total_fails=$((total_fails + f))
done
echo "banc a122 (halo commun, pastilles) : $total_checks vérification(s), $total_fails échec(s)"
exit $((total_fails > 0))
