#!/usr/bin/env bash
# Banc hors Studio d'a154 (vague 46, 2026-11-14, Cantin) : UiFeelController.
#   item   : objet ramené en zone safe (remote ItemSecured(itemId), UnboxService) : même arrivée que le colis (sons,
#            flash, zoom, UI_Escape), BoxIcon = ICON_<ItemId>, sinon ICON_BOX_<Rareté du catalogue> ; Title « Item
#            secured! » et Subtitle « Rare Smartphone » le temps de l'écran, puis les textes de Clément ; colis :
#            rien ne change (textes de Clément) ;
#   reveal : RevealFlash (révélation d'un colis ouvert, ShelfOpenController) : flash et zoom sans bannière ni son ;
#            révélation puis arrivée, arrivée puis révélation, deux révélations : un seul écran, caméra jamais
#            bloquée en zoom, rien n'est laissé ; pendant une poursuite, la caméra retrouve son ChaseFov.
# Faux Roblox et montage du banc a75 (copie a85 : a62-banc/autres-bancs/a60-banc + ext-a75 et setup-a75).
# Le branchement de ShelfOpenController est vérifié par la copie a154 du banc a104 (autres-bancs/a104).
#   bash run.sh [racine du dépôt] [scénarios…]   (défaut : /f/StealAShop)   VERBOSE=1 : lignes ok
set -u
H="$(cd "$(dirname "$0")" && pwd)"
B60="$H/../a62-banc/autres-bancs/a60-banc"
A75="$H/../a85-banc/autres-bancs/a75-banc"
ROOT="${1:-/f/StealAShop}"
shift || true
SRC="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
SCENARIOS="${*:-item reveal}"
if ! grep -q "RevealFlash" "$SRC/client/Controllers/UiFeelController.luau" 2>/dev/null; then
	echo "banc a154 (objet ramené, flash de la révélation) : SAUTÉ, pas de RevealFlash dans UiFeelController (a154 pas encore fusionné) : 0 vérification(s), 0 échec(s)"
	exit 0
fi
FILES60="shared client/Controllers/UI client/Controllers/HudController.luau client/Controllers/GainController.luau client/Controllers/UiFeelController.luau client/Controllers/NotifyController.luau"
sources() {
	(cd "$SRC" && find $1 -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
}
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
total_checks=0
total_fails=0
for name in $SCENARIOS; do
	OUT="$TMP/run.$name.luau"
	{
		if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; fi
		cat "$B60/stubs.luau" "$B60/ext-motion.luau" "$B60/ext-a60.luau" "$A75/ext-a75.luau"
		sources "$FILES60"
		cat "$B60/setup.luau" "$B60/setup-a60.luau" "$A75/setup-a75.luau" "$H/tests.$name.luau"
	} > "$OUT"
	out=$("$LUAU" "$(cygpath -w "$OUT")" 2>&1)
	line=$(printf '%s\n' "$out" | grep -E "^(scénario .* : )?[0-9]+ vérification\(s\), [0-9]+ échec\(s\)$" | tail -1)
	if [ -z "$line" ]; then
		printf '%s\n' "$out" | tail -25
		echo "scénario $name : arrêté avant la fin (erreur ci-dessus)"
		total_fails=$((total_fails + 1))
		continue
	fi
	if [ "${VERBOSE:-}" = "1" ]; then printf '%s\n' "$out"; else printf '%s\n' "$out" | grep -E "ÉCHEC|ERREUR" || true; fi
	c=$(printf '%s' "$line" | sed -E 's/^(scénario .* : )?([0-9]+) vérification.*/\2/')
	f=$(printf '%s' "$line" | sed -E 's/.*, ([0-9]+) échec.*/\1/')
	echo "  $name : $c contrôles, $f raté(s)"
	total_checks=$((total_checks + c))
	total_fails=$((total_fails + f))
done
echo "banc a154 (objet ramené, flash de la révélation) : $total_checks vérification(s), $total_fails échec(s)"
exit $((total_fails > 0))
