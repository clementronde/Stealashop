#!/usr/bin/env bash
# f70c3b (Cantin, 18/11 : plus de ralentissement quand le vigile est tout près du voleur) : lance un banc existant sur une
# copie de l'arbre à Chase.ApproachSlowNear = true (l'approche lente d'a224, la règle d'avant). Pour les bancs qui
# vérifient cette approche lente ; la nouvelle règle est vérifiée par le banc f70c3 (scénario proche). Arbre sans
# l'interrupteur à false : le banc tel quel.
#   bash lent.sh <script du banc> <racine du dépôt> [arguments…]
set -u
SCRIPT="$1"
REPO="${2%/src}"
shift 2
if ! grep -q "ApproachSlowNear = false," "$REPO/src/shared/Config/Chase.luau" 2>/dev/null; then
	exec bash "$SCRIPT" "$REPO" "$@"
fi
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
for d in src tools docs; do
	if [ -d "$REPO/$d" ]; then cp -r "$REPO/$d" "$TMP/$d"; fi
done
sed -i -e 's/ApproachSlowNear = false,/ApproachSlowNear = true,/' "$TMP/src/shared/Config/Chase.luau"
bash "$SCRIPT" "$TMP" "$@"
