#!/usr/bin/env bash
# Copie a159 (2026-11-14, vague 50, L-163) de la copie a141 : la porte se casse en 40 coups (plus long), la publication de SafeSlots par PvPService tombe alors entre deux contrôles et réécrit la valeur posée à la main ; tests.pvp.luau pose les mêmes présentoirs à l abri par PvPService.GetVaultSlots (même valeur « 1,3 » publiée par le serveur). Arbre sans PvP.DoorHits : lance la copie a141.
# Copie a141 (2026-11-14, L-142) : la section a14 vient de la copie a141 (../a14-banc, halos aux valeurs de Clément) ; sur un arbre sans a141, relance le banc a129 : bon avant et après la fusion.
# Banc hors Studio d'a129 (vague 39, 2026-11-14, optimisation téléphone ; audit docs/claude/notes/perf-telephone.md) :
#   halo : DisplayController et Config/DisplayHalo (lumière et particules des halos exposés coupées au-delà de 50 studs,
#          écart de 5, rien sous VISUAL EFFECTS OFF ; rayons tournés seulement dans le champ de la caméra ; teintes
#          du Secret réutilisées) ; inséré dans le banc a14 (copie a129, faux Camera avec FieldOfView et ViewportSize)
#          juste avant sa section 11 : le total compte aussi les 190 vérifications d'a14 ;
#   pvp  : PvPController ne revoit les objets d'une boutique qu'au tour où son état change, invites au même tour
#          qu'avant (entrée, sortie, SafeSlots), tout de suite au signal Carrying ; faux Roblox et mise en place du
#          banc a29 (copie a36), lus sur place.
# Sur un arbre sans Config/DisplayHalo (avant a129) : « SAUTÉ ».
#   bash run.sh [racine du dépôt] [scénarios…]   (défaut : /f/StealAShop ; scénarios : halo pvp)
#   VERBOSE=1 bash run.sh                         écrit aussi les lignes ok
set -u
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop}"
shift || true
SRC="$ROOT/src"
if ! grep -q "SPARKLE_EMISSION" "$SRC/shared/RarityHalo.luau" 2>/dev/null; then exec bash "/c/Users/user/AppData/Local/Claude-Data/claude_pzs8sxrjxfjjc/side-session-notes/local_8069c51a-7fa2-4234-b865-b99cadfc62e3/a129-banc/run.sh" "$ROOT" "$@"; fi
LUAU="$HOME/.rokit/bin/luau.exe"
SCENARIOS="${*:-halo pvp}"
if ! grep -q "DoorHits = " "$SRC/shared/Config/PvP.luau" 2>/dev/null; then exec bash "$H/../../../a141-banc/autres-bancs/a129-banc/run.sh" "$ROOT" "$@"; fi
if [ ! -f "$SRC/shared/Config/DisplayHalo.luau" ]; then
	echo "banc a129 (halos et invites sur téléphone) : SAUTÉ, a129 pas encore fusionné : 0 vérification(s), 0 échec(s)"
	exit 0
fi
A14="$H/../../../a141-banc/autres-bancs/a14-banc"
O29="/c/Users/user/AppData/Local/Claude-Data/claude_pzs8sxrjxfjjc/side-session-notes/local_8069c51a-7fa2-4234-b865-b99cadfc62e3/a36-banc/autres-bancs/a29-banc"
sources() {
	(cd "$SRC" && find $1 -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
}

total_checks=0
total_fails=0
for name in $SCENARIOS; do
	: "${R1_D:=$(d="${R1_RUN:-${TMPDIR:-/tmp}/r1-bancs}"; mkdir -p "$d" && mktemp -d "$d/b.XXXXXX")}" "${R1_D:?r1 : dossier du banc introuvable}"; OUT="$R1_D/run.$name.luau"
	if [ "$name" = "halo" ]; then
		{
			if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; fi
			cat "$A14/stubs.luau"
			sources "shared server/Services/DisplayService.luau client/Controllers/DisplayController.luau"
			awk '/^print\("== 11\. /{ exit } { print }' "$A14/tests.luau"
			cat "$H/tests.halo.luau"
			awk 'found { print; next } /^print\("== 11\. /{ found = 1; print }' "$A14/tests.luau"
		} > "$OUT"
	else
		{
			if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; fi
			cat "$O29/stubs.luau" "$O29/ext29.luau" "$O29/../stub-anticheat.luau"
			sources "shared server/Services/PvPService.luau server/Services/DisplayService.luau server/Services/PlotService.luau server/Services/WindowService.luau server/Services/CarryService.luau client/Controllers/PvPController.luau"
			cat "$O29/setup.luau" "$H/tests.$name.luau"
		} > "$OUT"
	fi
	out=$("$LUAU" "$(cygpath -w "$OUT")" 2>&1)
	line=$(printf '%s\n' "$out" | grep -E "[0-9]+ vérification\(s\), [0-9]+ échec\(s\)$" | tail -1)
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
	c=$(printf '%s' "$line" | sed -E 's/.*[^0-9]([0-9]+) vérification.*/\1/; s/^([0-9]+) vérification.*/\1/')
	f=$(printf '%s' "$line" | sed -E 's/.*, ([0-9]+) échec.*/\1/')
	echo "  $name : $c contrôles, $f raté(s)"
	total_checks=$((total_checks + c))
	total_fails=$((total_fails + f))
done
echo "banc a129 (halos et invites sur téléphone) : $total_checks vérification(s), $total_fails échec(s)"
exit $((total_fails > 0))
