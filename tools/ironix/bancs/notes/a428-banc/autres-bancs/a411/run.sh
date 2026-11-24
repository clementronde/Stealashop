#!/usr/bin/env bash
# a428 (lot100, 24/11) : copie du banc a411 ; C18 suit Config/Disguise.OnePerZone (L-328 point 2), faux Transfer et policiers en Model. Banc a411 (vague GC6, 23/11, L-113 : cabine d essayage) : DisguiseService, Config/Disguise, tuile FittingRoom de
# Config/SkillTree, remotes Disguise et Denounce de Net/Definitions. Faux Roblox minimal à lui (tests.luau : Vector3,
# CFrame sans rotation, Instances, Humanoid avec ApplyDescription qui attend, temps simulé) ; les autres services sont
# des bouchons (AntiCheat, Bat, Carry, Guard, NightCycle, Plot, SkillTree, StoreHeist, Window, Witness), Net aussi.
# Vrai : DisguiseService, Config/Disguise, Config/Features, Config/SkillTree, Contract/Find, WitnessGauge, Net/Definitions.
#   bash run.sh [racine du dépôt]   (défaut : /f/StealAShop)   VERBOSE=1 : lignes ok
# Arbre sans DisguiseService : « SAUTÉ ».
set -u
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop}"
ROOT="${ROOT%/src}"
SRC="$ROOT/src"
NAME="banc a411"
LUAU="$HOME/.rokit/bin/luau.exe"
if [ ! -f "$SRC/server/Services/DisguiseService.luau" ]; then
	echo "$NAME : SAUTÉ (pas de DisguiseService dans cet arbre) : 0 vérification(s), 0 échec(s)"
	exit 0
fi
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
OUT="$TMP/a411.luau"
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
