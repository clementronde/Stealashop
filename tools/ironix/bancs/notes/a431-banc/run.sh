#!/usr/bin/env bash
# Banc a431 (24/11, L-332, Cantin) : arbre de compétences, ce que fait chaque compétence. Lit les vrais modules
# Config/DeepFreeze, Features, Potions, PvP, Disguise et SkillTree du dépôt (sans Roblox : `script.Parent`, `require` et `Color3`
# simulés), puis tests.luau : une Description par compétence, des Labels chiffrés à chaque niveau tirés des Effects et
# des autres Config, jamais « — » ni un mot en capitale (qui remplacerait le nom de la tuile).
# Arbre sans a431 (pas de Description dans Config/SkillTree) : « SAUTÉ ».
#   bash run.sh [racine du dépôt]        VERBOSE=1 : sortie complète
set -u
H="$(cd "$(dirname "$0")" && pwd)"
ARG="${1:-/f/StealAShop}"
REPO="${ARG%/src}"
C="$REPO/src/shared/Config"
LUAU="$HOME/.rokit/bin/luau.exe"
LABEL="banc a431 (arbre : phrases et Labels chiffrés, L-332)"
if ! grep -q "Description = " "$C/SkillTree.luau"; then
	echo "$LABEL : SAUTÉ, pas de Description dans Config/SkillTree (a431 pas encore fusionné) : 0 vérification(s), 0 échec(s)"
	exit 0
fi
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
mod() { # nom de variable, fichier : le module dans une fonction, `script` et `require` simulés
	echo "local $1 = (function()"
	echo "local script = { Parent = CONFIG }"
	echo "local require = function(m) return m end"
	tr -d '\r' < "$2" | sed -E 's/^export type /type /; s/^--!strict//'
	echo "end)()"
	echo "CONFIG.$1 = $1"
}
{
	echo "local CONFIG = {}"
	echo "Color3 = { fromRGB = function(r, g, b) return { r, g, b } end, new = function(r, g, b) return { r, g, b } end } -- Config/Disguise (FallbackSkin…)"
	mod DeepFreeze "$C/DeepFreeze.luau"
	for m in Features PvP Potions Disguise SkillTree; do mod "$m" "$C/$m.luau"; done
	tr -d '\r' < "$H/tests.luau"
} > "$T/banc.luau"
out=$("$LUAU" "$(cygpath -w "$T/banc.luau")" 2>&1)
if [ "${VERBOSE:-}" = "1" ]; then printf '%s\n' "$out"; else printf '%s\n' "$out" | grep -E "ÉCHEC|error|Error" | head -20; fi
line=$(printf '%s\n' "$out" | grep -E "^a431 : [0-9]+ vérification" | tail -1)
if [ -z "$line" ]; then
	printf '%s\n' "$out" | tail -10
	echo "$LABEL : arrêté avant la fin : 0 vérification(s), 1 échec(s)"
	exit 1
fi
c=$(printf '%s' "$line" | sed -E 's/.* ([0-9]+) vérification.*/\1/')
f=$(printf '%s' "$line" | sed -E 's/.*, ([0-9]+) échec.*/\1/')
echo "$LABEL : $c vérification(s), $f échec(s)"
exit $((f > 0))
