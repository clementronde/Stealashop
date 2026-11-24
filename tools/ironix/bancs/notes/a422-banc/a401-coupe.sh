#!/usr/bin/env bash
# a401 (vague GC4, 23/11) : lance un banc existant sur une copie de l'arbre aux interrupteurs d'a401 coupés
# (Config/Vfx.Collect.Fountain, Config/Vfx.CollectPad, Config/UiMotion.CollectFeel et CollectFeel.Text : lignes
# « Enabled = true, -- a401 : interrupteur … » passées à false : règles d'avant, billets tous ensemble, chiffre au
# contact). Pour les bancs qui vérifient l'ancien rythme ; le nouveau est vérifié par le banc a401. Arbre sans a401 :
# le banc tel quel.
#   bash a401-coupe.sh <script du banc> <racine du dépôt> [arguments…]
set -u
SCRIPT="$1"
REPO="${2%/src}"
shift 2
if ! grep -q "a401 : interrupteur" "$REPO/src/shared/Config/Vfx.luau" 2>/dev/null; then
	exec bash "$SCRIPT" "$REPO" "$@"
fi
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
for d in src tools; do # docs (plus de 400 Mo) : pas lus par ces bancs
	if [ -d "$REPO/$d" ]; then cp -r "$REPO/$d" "$TMP/$d"; fi
done
sed -i -E 's/Enabled = true, -- a401 : interrupteur/Enabled = false, -- a401 : interrupteur/' "$TMP/src/shared/Config/Vfx.luau" "$TMP/src/shared/Config/UiMotion.luau"
bash "$SCRIPT" "$TMP" "$@"
