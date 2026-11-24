#!/usr/bin/env bash
# a226 (vague 68) : lance un banc existant sur une copie de l'arbre remise comme avant a226 (avant.sed : puissances et
# prix des armes, prix des auras et des traînées, proposition_v2 du simulateur, panneau de la dernière zone sans
# « ×2 players » ni couleur d'équipe). Pour les bancs qui écrivent en dur les dégâts du panneau, les PV des vitrines,
# les prix ou le texte « Strength 2M » ; les nouvelles valeurs et le panneau sont vérifiés par le banc a226 et par
# les copies a226 d'a94 et d'a101. Arbre sans a226 (pas de teamSuffix dans AdvicePanel) : le banc sur l'arbre tel quel.
#   bash avant.sh <lanceur du banc> <racine du dépôt, ou son dossier src> [autres arguments]
set -u
H="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$1"
REPO="${2%/src}"
TAIL="${2#"$REPO"}" # « /src » quand le lanceur prend le dossier src (a08)
shift 2
if ! grep -q "teamSuffix" "$REPO/src/shared/AdvicePanel.luau" 2>/dev/null; then
	exec bash "$SCRIPT" "$REPO$TAIL" "$@"
fi
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
for d in src tools docs; do
	if [ -d "$REPO/$d" ]; then cp -r "$REPO/$d" "$TMP/$d"; fi
done
for f in "$REPO"/*.md; do
	if [ -f "$f" ]; then cp "$f" "$TMP/"; fi
done
for f in "$TMP/src/shared/Config/Tools.luau" "$TMP/src/shared/Config/Cosmetics.luau" "$TMP/src/shared/AdvicePanel.luau" "$TMP/tools/ironix/equilibrage/proposition_v2.luau"; do
	if [ -f "$f" ]; then sed -b -i -f "$H/avant.sed" "$f"; fi
done
bash "$SCRIPT" "$TMP$TAIL" "$@"
