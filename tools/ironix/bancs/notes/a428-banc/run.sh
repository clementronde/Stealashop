#!/usr/bin/env bash
# Banc a428 (lot100, 24/11, L-326 et L-328 : cabine d'essayage) : zones ouvertes par les renaissances et plusieurs
# déguisés par zone (point 2), objet du voleur rendu au dénonciateur quand la police de sa dénonciation l'attrape
# (point 7, Features.DenounceRecover, CarryService.Transfer bouchonné), invite de la cabine sur PromptPart (lecture du
# client). Faux Roblox : celui du banc a411 (copie a428-banc/autres-bancs/a411/tests.luau, jusqu'à la section A).
#   bash run.sh [racine du dépôt]   (défaut : /f/StealAShop)   VERBOSE=1 : lignes ok
# Arbre sans Features.DenounceRecover : « SAUTÉ ».
set -u
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop}"
ROOT="${ROOT%/src}"
SRC="$ROOT/src"
NAME="banc a428"
LUAU="$HOME/.rokit/bin/luau.exe"
if ! grep -q "DenounceRecover" "$SRC/shared/Config/Features.luau" 2>/dev/null; then
	echo "$NAME : SAUTÉ (pas de Features.DenounceRecover dans cet arbre) : 0 vérification(s), 0 échec(s)"
	exit 0
fi
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
OUT="$TMP/a428.luau"
{
	echo "--!nocheck"
	echo "REAL_PRINT = print"
	if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; else echo "VERBOSE = false"; fi
	echo "SOURCES = {}"
	for f in shared/Config/DeepFreeze.luau shared/Config/Features.luau shared/Config/SkillTree.luau shared/Config/Disguise.luau shared/Contract/Find.luau shared/WitnessGauge.luau shared/Net/Definitions.luau server/Services/DisguiseService.luau; do
		printf 'SOURCES["%s"] = [==========[\n' "${f%.luau}"
		tr -d '\r' < "$SRC/$f"
		printf '\n]==========]\n'
	done
	printf 'CLIENT_SRC = [==========[\n'
	tr -d '\r' < "$SRC/client/Controllers/DisguiseController.luau"
	printf '\n]==========]\n'
	printf 'CARRY_SRC = [==========[\n'
	tr -d '\r' < "$SRC/server/Services/CarryService.luau"
	printf '\n]==========]\n'
	tr -d '\r' < "$H/autres-bancs/a411/tests.luau" | sed '/^-* A\. configuration et remotes/,$d'
	tr -d '\r' < "$H/tests.luau"
} > "$OUT"
out=$("$LUAU" "$(cygpath -w "$OUT")" 2>&1)
line=$(printf '%s\n' "$out" | grep -E "^$NAME : [0-9]+ vérification\(s\), [0-9]+ échec\(s\)$" | tail -1)
if [ -z "$line" ]; then
	printf '%s\n' "$out" | tail -25
	echo "$NAME : arrêté avant la fin (erreur ci-dessus) : 1 vérification(s), 1 échec(s)"
	exit 1
fi
if [ "${VERBOSE:-}" = "1" ]; then printf '%s\n' "$out"; else printf '%s\n' "$out" | grep -E "ÉCHEC|ERREUR" || true; fi
echo "$line"
f=$(printf '%s' "$line" | sed -E 's/.*, ([0-9]+) échec.*/\1/')
exit $((f > 0))
