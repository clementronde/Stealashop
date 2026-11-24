#!/usr/bin/env bash
# Banc a269 (Cantin, 20/11 : « les PNJ dans les zones arrêtent de se rentrer dedans ») : vrais WitnessService et
# Npc/NpcAvoid, harnais a100 (copie a151, témoins) ; faux vigiles pilotés par NpcAvoid.GuardAim (GuardService.moveTo).
# Parties « on » (Witness.Avoid.Enabled = true) et « off » (Enabled = false : comportement d'avant), puis la foule
# (crowd-run.sh : Crowd.Spacing, faux Roblox du banc a240 crowd).
# « SAUTÉ » sur un arbre sans Npc/NpcAvoid (avant a269).
set -u
H="$(cd "$(dirname "$0")" && pwd)"
A100="$H/../a151-banc/autres-bancs/a100/witness"
ROOT="${1:-/f/StealAShop}"
SRC="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
NAME="banc a269"
if [ ! -f "$SRC/server/Services/Npc/NpcAvoid.luau" ]; then
	echo "$NAME : SAUTÉ, pas de Npc/NpcAvoid : 0 vérification(s), 0 échec(s)"
	exit 0
fi
FILES="server/Services/WitnessService.luau server/Services/Npc/NpcAvoid.luau server/Services/Npc/WitnessLanes.luau shared/WitnessGauge.luau"
for m in Balance Cosmetics DeepFreeze Features Items Rarities Tools Witness Zones; do
	FILES="$FILES shared/Config/$m.luau"
done
for m in Animations Find Models UI; do
	FILES="$FILES shared/Contract/$m.luau"
done
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
total=0; fails=0
for part in on off; do
	OUT="$TMP/$part.luau"
	{
		if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; else echo "VERBOSE = false"; fi
		if [ "$part" = "off" ]; then echo "AVOID_OFF = true"; else echo "AVOID_OFF = false"; fi
		echo "SOURCES = {}"
		printf '%s\n' $FILES | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
		tr -d '\r' < "$A100/harness.luau"
		tr -d '\r' < "$H/tests.luau"
	} > "$OUT"
	out=$("$LUAU" "$(cygpath -w "$OUT")" 2>&1)
	line=$(printf '%s\n' "$out" | grep -E "^$NAME $part : [0-9]+ vérification\(s\), [0-9]+ échec\(s\)$" | tail -1)
	if [ -z "$line" ]; then
		printf '%s\n' "$out" | tail -25
		echo "$NAME $part : arrêté avant la fin (erreur ci-dessus)"
		fails=$((fails + 1))
		continue
	fi
	if [ "${VERBOSE:-}" = "1" ]; then printf '%s\n' "$out"; else printf '%s\n' "$out" | grep -E "ÉCHEC|ERREUR" || true; fi
	echo "$line"
	c=$(printf '%s' "$line" | sed -E 's/.* : ([0-9]+) vérification.*/\1/'); f=$(printf '%s' "$line" | sed -E 's/.*, ([0-9]+) échec.*/\1/')
	total=$((total + c)); fails=$((fails + f))
done
# Partie foule (WitnessCrowdController, Crowd.Spacing) : crowd-run.sh
out=$(bash "$H/crowd-run.sh" "$ROOT" 2>&1)
printf '%s\n' "$out" | grep -vE "^banc a269 crowd : "
line=$(printf '%s\n' "$out" | grep -E "^banc a269 crowd : [0-9]+ vérification\(s\), [0-9]+ échec\(s\)$" | tail -1)
if [ -z "$line" ]; then fails=$((fails + 1)); else
	c=$(printf '%s' "$line" | sed -E 's/.* : ([0-9]+) vérification.*/\1/'); f=$(printf '%s' "$line" | sed -E 's/.*, ([0-9]+) échec.*/\1/')
	total=$((total + c)); fails=$((fails + f))
fi
echo "$NAME (PNJ qui se croisent sans se toucher, foule espacée) : $total vérification(s), $fails échec(s)"
exit $((fails > 0))
