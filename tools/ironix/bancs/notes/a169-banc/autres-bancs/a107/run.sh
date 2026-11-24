#!/usr/bin/env bash
# Copie a169 (2026-11-15, vague 52, lot C : le tuto sans colis) de la copie a134 du banc a107 : la passe « ancien »
# (Features.ShelfOpen = false) lit la copie a169 du banc a28 (../a28) : le tuto ne lit plus l'interrupteur, le même déroulé
# à objets doit passer ; passe « nouveau » : bulles des étapes 3 et 4 sans ShelfBubble, TakeUnlocked puis DisplayUnlocked (en main).
# Arbre sans ProtectShop dans Config/Tutorial (avant a169) : relance la copie a134.
if ! grep -q "ProtectShop" "${1:-/f/StealAShop}/src/shared/Config/Tutorial.luau" 2>/dev/null; then exec bash "$(cd "$(dirname "$0")/../../.." && pwd)/a134-banc/autres-bancs/a107/run.sh" "$@"; fi
# Copie a134 (2026-11-14, vague 40, rééquilibrage v2 appliqué dans src/) : étape 6 au tapis seul (plus de banc), coups espacés (5 par seconde en débit régulier).
# Arbre sans le rééquilibrage (Balance.Stats.WalkPerDecade absent) : le banc d'avant tourne tel quel.
_A134_R="${1:-/f/StealAShop}"; _A134_F="$_A134_R/src/shared/Config/Balance.luau"; [ -f "$_A134_F" ] || _A134_F="$_A134_R/shared/Config/Balance.luau"
if ! grep -q "WalkPerDecade" "$_A134_F" 2>/dev/null; then exec bash "$(cd "$(dirname "$0")" && pwd)/../../../a126-banc/autres-bancs/a107-banc/run.sh" "$@"; fi
# Copie d'a126 (vague 38, 2026-11-14) de la copie a121 du banc a107 : la passe « ancien » lit la copie a126 du banc a28
# (14 étapes) et tests.a107.luau d'ici attend 14 étapes. Sur un arbre sans EscapeBot (avant a126), relance la copie d'a121.
if ! grep -q "EscapeBot" "${1:-/f/StealAShop}/src/shared/Config/Tutorial.luau" 2>/dev/null; then exec bash "$(cd "$(dirname "$0")/../../.." && pwd)/a121-banc/autres-bancs/a107-banc/run.sh" "$@"; fi
# Copie d'a121 (vague 36, 2026-11-13, L-085 point 4) du banc a107 : la passe « ancien » lit la copie a121 du banc a28
# (a121-banc/autres-bancs/a28-banc : 13 étapes) et tests.a107.luau d'ici (« mêmes 10 premières étapes », 13 en tout).
# Sur un arbre sans BotShopRadius dans Config/Tutorial (avant a121), relance le banc a107 d'origine : bon avant et après la fusion.
if ! grep -q "BotShopRadius" "${1:-/f/StealAShop}/src/shared/Config/Tutorial.luau" 2>/dev/null; then exec bash "$(cd "$(dirname "$0")/../../.." && pwd)/a107-banc/run.sh" "$@"; fi
# Banc hors Studio d'a107 (vague 31, 2026-11-12, L-112) : le tuto avec l'ouverture des colis sur le rayon.
# Deux passes sur le faux Roblox et les faux services du banc a28 (copie active : a59-banc/autres-bancs/a28-banc,
# lus sur place, rien de copié) :
#   1. « ancien » : Config/Features lu avec ShelfOpen = false, tout le banc a28 : l'ancien tuto exact ;
#   2. « nouveau » : ShelfOpen = true, la mise en place d'a28 (jusqu'à « == A. ») puis tests.a107.luau :
#      colis ouvert sur le rayon, objet sorti, porté, rangé, posé sous antivol, UNLOCKED!, présentoir, reprises.
# Sur un arbre sans StoreHeistService.SetLuckOverride (avant a107) : « SAUTÉ ».
#   bash run.sh [racine du dépôt]   (défaut : /f/StealAShop)
#   VERBOSE=1 bash run.sh            écrit aussi les lignes ok
set -u
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop}"
SRC="$ROOT/src"
A28="$H/../a28" # copie a134 : les scénarios d'a28 mis à jour (a134-banc/autres-bancs/a28)
LUAU="$HOME/.rokit/bin/luau.exe"
if ! grep -q "SetLuckOverride" "$SRC/server/Services/StoreHeistService.luau" 2>/dev/null; then
	echo "banc a107 (tuto L-112) : SAUTÉ (arbre d'avant a107), 0 vérification(s), 0 échec(s)"
	exit 0
fi
FILES="shared server/Services/TutorialService.luau client/Controllers/TutorialController.luau"
sources() { # $1 = valeur de Features.ShelfOpen
	(cd "$SRC" && find $FILES -name '*.luau' | sort) | awk -v root="$SRC" -v shelf="$1" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); if (f == "shared/Config/Features.luau") { n = gsub(/ShelfOpen = (true|false)/, "ShelfOpen = " shelf, c); if (n != 1) { print "error(\"a107 : ShelfOpen introuvable dans Config/Features\")" } } printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
}
total_checks=0
total_fails=0
for mode in ancien nouveau; do
	: "${R1_D:=$(d="${R1_RUN:-${TMPDIR:-/tmp}/r1-bancs}"; mkdir -p "$d" && mktemp -d "$d/b.XXXXXX")}" "${R1_D:?r1 : dossier du banc introuvable}"; OUT="$R1_D/run.$mode.luau"
	{
		if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; fi
		cat "$A28/stubs.luau" "$A28/ext.luau" "$A28/ext28.luau"
		if [ "$mode" = "ancien" ]; then
			sources false
			cat "$A28/tests.luau"
		else
			sources true
			awk '/^print\("== A\. Config\/Tutorial"\)/ { exit } { print }' "$A28/tests.luau"
			cat "$H/tests.a107.luau"
		fi
	} > "$OUT"
	out=$("$LUAU" "$(cygpath -w "$OUT")" 2>&1)
	line=$(printf '%s\n' "$out" | grep -E "^[0-9]+ vérification\(s\), [0-9]+ échec\(s\)$" | tail -1)
	if [ -z "$line" ]; then
		printf '%s\n' "$out" | tail -25
		echo "passe $mode : arrêtée avant la fin (erreur ci-dessus)"
		total_fails=$((total_fails + 1))
		continue
	fi
	if [ "${VERBOSE:-}" = "1" ]; then printf '%s\n' "$out"; else printf '%s\n' "$out" | grep -E "ÉCHEC|ERREUR" || true; fi
	c=$(printf '%s' "$line" | sed -E 's/^([0-9]+) vérification.*/\1/')
	f=$(printf '%s' "$line" | sed -E 's/.*, ([0-9]+) échec.*/\1/')
	echo "  passe $mode (ShelfOpen = $([ "$mode" = ancien ] && echo false || echo true)) : $c contrôles, $f raté(s)"
	total_checks=$((total_checks + c))
	total_fails=$((total_fails + f))
done
echo "banc a107 (tuto L-112) : $total_checks vérification(s), $total_fails échec(s)"
exit $((total_fails > 0))
