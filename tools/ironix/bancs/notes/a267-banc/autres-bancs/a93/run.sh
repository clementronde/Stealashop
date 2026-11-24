#!/usr/bin/env bash
# a267 (vague 80, 2026-11-20) : le banc a93 (lanceur a262-banc/autres-bancs-cantin/a93) sur une copie de l'arbre à
# Traps = false : son scénario attend la tuile Traps en « Soon » (pièges allumés en DEV par a267, vérifiés par a243
# et a267). Arbre à Traps = false : le banc tel quel.
set -u
H="$(cd "$(dirname "$0")/../../.." && pwd)"
REPO="${1%/src}"
TAIL="${1#"$REPO"}"
shift
if ! grep -q "Traps = true," "$REPO/src/shared/Config/Features.luau" 2>/dev/null; then
	exec bash "$H/a262-banc/autres-bancs-cantin/a93/run.sh" "$REPO$TAIL" "$@"
fi
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
for d in src tools docs; do
	if [ -d "$REPO/$d" ]; then cp -r "$REPO/$d" "$TMP/$d"; fi
done
for f in "$REPO"/*.md; do
	if [ -f "$f" ]; then cp "$f" "$TMP/"; fi
done
sed -i 's/^\tTraps = true,/\tTraps = false,/' "$TMP/src/shared/Config/Features.luau"
grep -q "Traps = false," "$TMP/src/shared/Config/Features.luau" || { echo "banc a93 (tuile Walls) : Traps introuvable dans Features : 0 vérification(s), 1 échec(s)"; exit 1; }
bash "$H/a262-banc/autres-bancs-cantin/a93/run.sh" "$TMP$TAIL" "$@"
