#!/usr/bin/env bash
# Banc hors Studio d'a141 (2026-11-14, L-141 : boutique « Steal a … », allée centrale, deux files face à face,
# 48 studs de large au lieu de 64) :
#   rayon    RayonService cache et rend TOUS les contours RayonSpot_0n d'un rayon (deux par rayon : deux pièces
#            du même nom, ou un modèle qui en porte deux), valeurs d'origine rendues ; sur le faux Roblox et les
#            tests du banc a47 (lus sur place, son « summary » final retiré), plus tests.rayon.luau ;
#   restore  UnboxService, retour du joueur : un objet posé au sol avec l'ancienne forme revient dans
#            l'inventaire (antivol gardé) s'il ne tient plus entier dans Bounds ou s'il est sur un présentoir ;
#            mise en place du banc a105 lue sur place, plus tests.restore.luau.
# Sur un arbre sans spotsOf dans RayonService (avant a141) : « SAUTÉ ».
#   bash run.sh [racine du dépôt] [scénarios…]   (défaut : /f/StealAShop ; scénarios : rayon restore)
set -u
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop}"
shift || true
SRC="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
SCENARIOS="${*:-rayon restore}"
LABEL="banc a141 (boutique à deux files, L-141)"
if ! grep -q "spotsOf" "$SRC/server/Services/RayonService.luau" 2>/dev/null; then
	echo "$LABEL : SAUTÉ, a141 pas encore fusionné : 0 vérification(s), 0 échec(s)"
	exit 0
fi
A47="$H/../a47-banc"
A105="$H/../a105-banc"
B51="$A105/autres-bancs/a51-banc"
sources() { # liste de fichiers sous src
	(cd "$SRC" && find $1 -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
}

total_checks=0
total_fails=0
for name in $SCENARIOS; do
	: "${R1_D:=$(d="${R1_RUN:-${TMPDIR:-/tmp}/r1-bancs}"; mkdir -p "$d" && mktemp -d "$d/b.XXXXXX")}" "${R1_D:?r1 : dossier du banc introuvable}"; OUT="$R1_D/run.$name.luau"
	if [ "$name" = "rayon" ]; then
		{
			cat "$A47/stubs.luau"
			sources "shared server/Services/RayonService.luau client/Controllers/UpgradeController.luau server/Services/ShopStageService.luau"
			tr -d '\r' < "$A47/tests.luau" | sed -e '/^summary()$/d'
			cat "$H/tests.rayon.luau"
		} > "$OUT"
		out=$("$LUAU" "$(cygpath -w "$OUT")" 2>&1)
		line=$(printf '%s\n' "$out" | grep -E "^[0-9]+ vérification\(s\), [0-9]+ échec\(s\)$" | tail -1)
	else
		{
			cat "$B51/stubs.luau" "$B51/ext29.luau" "$B51/ext38.luau" "$B51/ext46.luau" "$B51/stub-anticheat.luau" "$B51/ext51.luau"
			sources "shared client/Controllers/UI server/Services/InventoryService.luau server/Services/IndexService.luau server/Services/MonetizationService.luau server/Services/DataService.luau server/Services/DisplayService.luau server/Services/PlotService.luau server/Services/TrainingService.luau server/Services/UnboxService.luau server/Services/StatsService.luau server/Services/ToolService.luau server/Services/ShopService.luau server/Services/PvPService.luau client/Controllers/UnboxController.luau client/Controllers/InventoryController.luau client/Controllers/Unbox"
			cat "$B51/features.luau" "$B51/pre.on.luau" "$B51/setup.luau" "$A105/ext105.luau" "$H/tests.$name.luau"
		} > "$OUT"
		out=$("$LUAU" "$(cygpath -w "$OUT")" 2>&1)
		line=$(printf '%s\n' "$out" | grep -E "^scénario .* : [0-9]+ vérification\(s\), [0-9]+ échec\(s\)$" | tail -1)
	fi
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
	c=$(printf '%s' "$line" | grep -oE "[0-9]+ vérification" | grep -oE "[0-9]+")
	f=$(printf '%s' "$line" | grep -oE "[0-9]+ échec" | grep -oE "[0-9]+")
	echo "  $name : $c contrôles, $f raté(s)"
	total_checks=$((total_checks + c))
	total_fails=$((total_fails + f))
done
echo "$LABEL : $total_checks vérification(s), $total_fails échec(s)"
exit $((total_fails > 0))
