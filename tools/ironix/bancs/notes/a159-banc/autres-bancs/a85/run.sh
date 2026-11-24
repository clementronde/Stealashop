#!/usr/bin/env bash
# Copie a159 (2026-11-14, vague 50, L-163) de la copie a98 : textes des tuiles (Reinforced Door 40 à 80, Walls I à IV, Lock 30s à 60s, Door Repair), Curtain (Lock) codée ; le refus « Coming soon » est vérifié sur Guards. Arbre sans PvP.DoorHits : lance la copie a98.
# 2026-11-12 (a98, vague 29) : copie de celle d'a93 ; tests.contract.luau : K1b accepte des écrans ajoutés après UI_SkillTree (UI_Admin, UI_PawnShop…), K1f lit la première entrée UI_HUD (une seconde, facultative, porte AdminButton) ; sans la tuile Walls, lance a85-banc-a88 (copie de celle d'a88, mêmes changements).
# Copie d'a93 (2026-11-12, vague 29, L-105 point 3) : la tuile ShopLevel devient Walls (Skill_Walls, textes « Walls ×1.25 », prix codés, Traps à Walls 2), cherchée sous son ancien nom Tile_ShopLevel (écran du relevé) ; contrat : Tile ou OldTiles. Sans la tuile Walls dans Config/SkillTree, lance le banc d'origine.
# 2026-11-11 (Ironix) : les entrées simulées sont dans le repère des AbsolutePosition (input.Position, mesuré en Play) ; seul GetMouseLocation ajoute INSET_Y. Nav ajoutait à tort GetGuiInset (clic 58 px trop bas).
# Banc hors Studio d'a85 (vague 27, 2026-11-11, L-096 point 2) : écran de l'arbre de compétences UI_SkillTree
# (SkillTreeController, SkillTree/Fx, SkillTree/Nav), bouton UI_HUD.SkillTreeButton, contrat UI_SkillTree.
#   tiles    : calques Bought / Available / Locked selon Skill_<Id> et OpensWhen, textes (Lv, TileName),
#              Price / PriceNeed / SOON / MAX, panneau (NodeName… BuyButton ou NeedButton), écran recréé,
#              rien d'autre que textes et visibilités ;
#   buy      : achat envoyé (BuySkill), 2e clic ignoré en attente, refus (secousse, UI_Deny, rien d'envoyé),
#              achat réussi (gonfle, éclat, étincelles, UI_Success, voisine découverte avec NEW!), argent qui
#              défile et sursaute, rien de laissé ;
#   nav      : NavLayer, clic sur une tuile (GetGuiInset), glisser (seuil, limite, élastique, retour), molette
#              (point fixe, bornes 0,75 et 1,8), pincement, zoom à l'ouverture sur petit écran ;
#   hud      : SkillTreeButton montré dans LeftRail et LeftRailTouch, ouvre et ferme (un seul état), téléphone
#              (LeftRailTouch montré, LeftRail caché), groupe Menu, « bop » de la tuile centrale vers les
#              anneaux, fermeture ;
#   contract : Contract/UI (UI_SkillTree, SkillTreeButton en double voulu) et ContractChecker sans ligne rouge.
# Faux Roblox : tiles, buy, nav, hud sur la copie d'a62 du banc a60 (a62-banc/autres-bancs/a60-banc) + ext85.luau ;
# contract sur la copie d'a62 du banc a39 (a62-banc/autres-bancs/a39-banc). Écrans : build85.luau (relevé).
#   bash run.sh [racine du dépôt] [scénarios…]   (défaut : /f/StealAShop)
#   VERBOSE=1 bash run.sh                         écrit aussi les lignes ok
set -u
H="$(cd "$(dirname "$0")" && pwd)"
B60="$H/../../../a62-banc/autres-bancs/a60-banc"
B39="$H/../../../a62-banc/autres-bancs/a39-banc"
ROOT="${1:-/f/StealAShop}"
shift || true
SRC="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
SCENARIOS="${*:-tiles buy nav hud contract}"
if ! grep -q "DoorHits = " "$SRC/shared/Config/PvP.luau" 2>/dev/null; then
	exec bash "$H/../../../a98-banc/autres-bancs/a85-banc/run.sh" "$ROOT" "$@"
fi
if ! grep -q "Id = \"Walls\"" "$SRC/shared/Config/SkillTree.luau" 2>/dev/null; then
	exec bash "$H/../a85-banc-a88/run.sh" "$ROOT" "$@"
fi
if [ ! -f "$SRC/client/Controllers/SkillTreeController.luau" ]; then
	echo "banc a85 (arbre de compétences, écran) : SAUTÉ, pas de Controllers/SkillTreeController.luau dans $SRC (a85 pas encore fusionné) : 0 vérification(s), 0 échec(s)"
	exit 0
fi
FILES60="shared client/Controllers/UI client/Controllers/SkillTree client/Controllers/SkillTreeController.luau client/Controllers/UiFeelController.luau"
FILES39="shared client/Controllers/UI server/Services/ContractChecker.luau"

sources() {
	(cd "$SRC" && find $1 -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
}

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
total_checks=0
total_fails=0
for name in $SCENARIOS; do
	OUT="$TMP/run.$name.luau"
	if [ "$name" = "contract" ]; then
		{
			if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; fi
			cat "$B39/stubs.luau" "$B39/ext29.luau" "$B39/ext38.luau"
			sources "$FILES39"
			cat "$B39/setup.luau" "$H/build85.luau" "$H/tests.$name.luau"
		} > "$OUT"
	else
		{
			cat "$B60/stubs.luau" "$B60/ext-motion.luau" "$B60/ext-a60.luau" "$H/ext85.luau"
			sources "$FILES60"
			cat "$B60/setup.luau" "$B60/setup-a60.luau" "$H/build85.luau" "$H/setup85.luau" "$H/tests.$name.luau"
		} > "$OUT"
	fi
	out=$("$LUAU" "$(cygpath -w "$OUT")" 2>&1)
	line=$(printf '%s\n' "$out" | grep -E "^(scénario .* : )?[0-9]+ vérification\(s\), [0-9]+ échec\(s\)$" | tail -1)
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
	c=$(printf '%s' "$line" | sed -E 's/^(scénario .* : )?([0-9]+) vérification.*/\2/')
	f=$(printf '%s' "$line" | sed -E 's/.*, ([0-9]+) échec.*/\1/')
	echo "  $name : $c contrôles, $f raté(s)"
	total_checks=$((total_checks + c))
	total_fails=$((total_fails + f))
done
echo "banc a85 (arbre de compétences, écran) : $total_checks vérification(s), $total_fails échec(s)"
exit $((total_fails > 0))
