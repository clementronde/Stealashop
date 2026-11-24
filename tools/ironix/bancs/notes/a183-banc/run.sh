#!/usr/bin/env bash
# Banc hors Studio d'a183 (2026-11-15, vague 56, L-173 : récompenses de renaissance = multiplicateur d'argent et
# tuiles de l'arbre, titre gardé). Côté client, sur le faux Roblox et l'écran construit du banc a85 (copie a159,
# faux Roblox d'a60 copie a62), avec le calque RebirthLocked ajouté par a183-banc/patches/a85.sed :
#   tiles    renaissance ouverte : calque RebirthLocked « REBIRTH n » / « TO UNLOCK », attribut RequiresRebirth,
#            tuile impossible à choisir, ouverte après la renaissance n, pas de « NEW! » sur une tuile encore fermée,
#            tuile déjà achetée jamais refermée
#   off      renaissance coupée (pas d'attribut Rebirths) : tuiles à renaissance cachées, sauf déjà achetées
#   locked   SkillTree.HideWhenRebirthOff = false (pre.locked.luau) : montrées verrouillées, renaissance coupée
#   nolayer  calque RebirthLocked pas encore livré : Locked à sa place
#   alert    RailAlertController : une tuile à renaissance fermée n'allume pas la pastille « ! » du bouton Upgrades
#   title    RebirthTitleController : BB_RebirthTitle sur la tête des joueurs qui ont fait une renaissance
# Le serveur (achat refusé puis permis après la renaissance n, profil sans renaissance, renaissance coupée), le
# multiplicateur et la fin des récompenses cosmétiques sont dans les sections « (a183) » ajoutées aux bancs a84,
# a164 et a39 (a183-banc/patches, a183-banc/lanceur.sh).
#   bash run.sh [racine du dépôt] [scénarios…]   (défaut : /f/StealAShop)
set -u
H="$(cd "$(dirname "$0")" && pwd)"
B60="$H/../a62-banc/autres-bancs/a60-banc"
A85="$H/../a159-banc/autres-bancs/a85"
ROOT="${1:-/f/StealAShop}"
shift || true
SRC="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
SCENARIOS="${*:-tiles off locked nolayer alert title}"
if ! grep -q "RequiresRebirth" "$SRC/shared/Config/SkillTree.luau" 2>/dev/null; then
	echo "banc a183 (récompenses de renaissance) : SAUTÉ, pas de RequiresRebirth dans Config/SkillTree de $SRC (a183 pas encore fusionné) : 0 vérification(s), 0 échec(s)"
	exit 0
fi
FILES="shared client/Controllers/UI client/Controllers/SkillTree client/Controllers/SkillTreeController.luau client/Controllers/UiFeelController.luau client/Controllers/RebirthTitleController.luau client/Controllers/RailAlertController.luau"

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
		cat "$B60/stubs.luau" "$B60/ext-motion.luau" "$B60/ext-a60.luau" "$A85/ext85.luau"
		sources "$FILES"
		if [ -f "$H/pre.$name.luau" ]; then cat "$H/pre.$name.luau"; fi
		cat "$B60/setup.luau" "$B60/setup-a60.luau" "$A85/build85.luau" "$A85/setup85.luau" "$H/tests.$name.luau"
	} > "$OUT"
	sed -E -i -f "$H/patches/a85.sed" "$OUT"
	out=$("$LUAU" "$(cygpath -w "$OUT")" 2>&1)
	line=$(printf '%s\n' "$out" | grep -E "^[0-9]+ vérification\(s\), [0-9]+ échec\(s\)$" | tail -1)
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
	c=$(printf '%s' "$line" | sed -E 's/^([0-9]+) vérification.*/\1/')
	f=$(printf '%s' "$line" | sed -E 's/.*, ([0-9]+) échec.*/\1/')
	echo "  $name : $c contrôles, $f raté(s)"
	total_checks=$((total_checks + c))
	total_fails=$((total_fails + f))
done
echo "banc a183 (récompenses de renaissance) : $total_checks vérification(s), $total_fails échec(s)"
exit $((total_fails > 0))
