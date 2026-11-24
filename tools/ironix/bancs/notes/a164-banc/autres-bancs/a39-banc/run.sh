#!/usr/bin/env bash
# Copie d a164 (2026-11-14, vague 51, renaissance V0) : tests.rebirth.luau attend le tableau V0 de la proposition
# (20B, Diamant géant ; ICON_Z6_DiamantGeant ajouté à setup.luau) ; nouveau scénario rebirthlive (attribut Rebirths : confirmation
# en 2 temps, envoi Rebirth). Arbre sans Rebirths.KeepItems (avant la fusion) : relance la copie a95.
# Copie d'a95 (2026-11-12, vague 29, receleur) : tests.contract.luau accepte le stand PawnShopStall à la fin de Models.List
# (après RobuxShopCounter) ; tests.pads.luau permet le seul avertissement « PawnShopController absent » (arbre sans lui).
# Bonne avant et après la fusion.
# Copie d'a62 (2026-11-11, vague 22, L-092 3g) : stubs.luau ajoute les signaux InputBegan et InputEnded
# (Motion.Button suit la fin du toucher). Tests inchangés.
# Banc hors Studio d'a39 (L-071, points 1 et 2) : boutons Shop, Index et Rebirth du HUD (HudController,
# Config/Features), vitrine de la boutique Robux (RobuxShopController : aucun appel à MarketplaceService,
# « Soon » ; achats normaux avec Features.RobuxShop = true), écran Rebirth en aperçu (RebirthController,
# Config/Rebirths), plaques ShopPad des comptoirs (ShopPadController et l'API Open des trois boutiques),
# contrat (Contract/Models, Contract/UI, ContractChecker).
# Vrais : Shared, Controllers/UI/Motion, HudController, RobuxShopController, WeaponShopController,
# AuraShopController, RebirthController, ShopPadController, ContractChecker (scénario contract). Le
# serveur n'est pas lancé (seul Net, pour créer les remotes).
# Faux Roblox : celui d'a38 (stubs.luau d'a36, ext29.luau, ext38.luau avec MarketplaceService), copié
# ici. Chaque scénario tourne dans son propre luau (état neuf) : pre.<nom>.luau s'il existe (live :
# boutique ouverte et Ids ; previewids : vitrine avec des Ids ; off : vitrine, aperçu et index
# coupés), setup.luau, puis tests.<nom>.luau.
#   bash run.sh [racine du dépôt] [scénarios…]   (défaut : le worktree a39 ; après fusion : /f/StealAShop)
#   VERBOSE=1 bash run.sh                         écrit aussi les lignes ok et la sortie des modules
set -u
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop/agents/a39}"
shift || true
SRC="$ROOT/src"
if ! grep -q "KeepItems = KEEP_ITEMS" "$SRC/shared/Config/Rebirths.luau" 2>/dev/null; then
	exec bash "$H/../../../a95-banc/autres-bancs/a39-banc/run.sh" "$ROOT" "$@"
fi
LUAU="$HOME/.rokit/bin/luau.exe"
SCENARIOS="${*:-preview previewids live off rebirth rebirthlive pads contract}"
# Arbre d'avant la fusion de L-071 (un autre agent lance run-all-bancs.sh sur son worktree) : rien à
# tester, on le dit et on passe.
if [ ! -f "$SRC/client/Controllers/ShopPadController.luau" ]; then
	echo "banc a39 (écrans du HUD, plaques ShopPad) : SAUTÉ, pas de ShopPadController.luau dans $SRC (L-071 pas encore fusionné) : 0 vérification(s), 0 échec(s)"
	exit 0
fi
FILES="shared client/Controllers/UI client/Controllers/HudController.luau client/Controllers/RobuxShopController.luau client/Controllers/WeaponShopController.luau client/Controllers/AuraShopController.luau client/Controllers/RebirthController.luau client/Controllers/ShopPadController.luau server/Services/ContractChecker.luau"

sources() {
	(cd "$SRC" && find $FILES -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
}

total_checks=0
total_fails=0
for name in $SCENARIOS; do
	: "${R1_D:=$(d="${R1_RUN:-${TMPDIR:-/tmp}/r1-bancs}"; mkdir -p "$d" && mktemp -d "$d/b.XXXXXX")}" "${R1_D:?r1 : dossier du banc introuvable}"; OUT="$R1_D/run.$name.luau"
	{
		if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; fi
		cat "$H/stubs.luau" "$H/ext29.luau" "$H/ext38.luau"
		sources
		if [ -f "$H/pre.$name.luau" ]; then cat "$H/pre.$name.luau"; fi
		cat "$H/setup.luau"
		cat "$H/tests.$name.luau"
	} > "$OUT"
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
		printf '%s\n' "$out" | grep -E "^---|ÉCHEC|ERREUR|^    " | grep -vE "^--- " || true
	fi
	c=$(printf '%s' "$line" | sed -E 's/.* : ([0-9]+) vérification.*/\1/')
	f=$(printf '%s' "$line" | sed -E 's/.*, ([0-9]+) échec.*/\1/')
	echo "  $name : $c contrôles, $f raté(s)"
	total_checks=$((total_checks + c))
	total_fails=$((total_fails + f))
done
echo "banc a39 (écrans du HUD, plaques ShopPad) : $total_checks vérification(s), $total_fails échec(s)"
exit $((total_fails > 0))
