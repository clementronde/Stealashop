#!/usr/bin/env bash
# Copie a134 (2026-11-14, vague 40, rééquilibrage v2 appliqué dans src/) : plus de banc : ni montée ni animation, côté serveur comme côté client ; harnais de la copie a134 d'a65.
# Arbre sans le rééquilibrage (Balance.Stats.WalkPerDecade absent) : le banc d'avant tourne tel quel.
_A134_R="${1:-/f/StealAShop}"; _A134_F="$_A134_R/src/shared/Config/Balance.luau"; [ -f "$_A134_F" ] || _A134_F="$_A134_R/shared/Config/Balance.luau"
if ! grep -q "WalkPerDecade" "$_A134_F" 2>/dev/null; then exec bash "$(cd "$(dirname "$0")" && pwd)/../../../a115-banc/run.sh" "$@"; fi
# Banc hors Studio d'a115 (2026-11-13, Cantin : montée instantanée au tapis et au banc, sortie du tapis au premier
# mouvement, TreadmillRun en boucle). Faux Roblox : harnais de la copie a115 du banc a65
# (autres-bancs/a65-banc/harness.luau, lu sur place) ; ext.luau ajoute le côté client (LocalPlayer, Humanoid
# MoveDirection et WalkSpeed, faux AnimationController, Net.Client) ; vrais TrainingService, TrainingController,
# Shared/TrainingZone, MachineVariantService, Config/Training, Upgrades, DeepFreeze, Net/RateLimiter.
# Mesures (lignes « MESURE ») : délai d'entrée (première image dans la zone → séance du serveur et animation chez
# le client) et sortie du tapis au premier mouvement.
# Sur un arbre sans Shared/TrainingZone (avant a115) : seulement les mesures « avant » du serveur, puis « SAUTÉ ».
#   bash run.sh [racine du dépôt]   (défaut : /f/StealAShop)
#   VERBOSE=1 bash run.sh           écrit aussi les lignes ok
set -u
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop}"
SRC="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
HARNESS="$H/../a65/harness.luau" # copie a134 : le harnais de la copie a134 d'a65 (faux Formulas complété)
FILES="server/Services/TrainingService.luau shared/TrainingZone.luau server/Services/MachineVariantService.luau shared/Config/Training.luau shared/Config/Upgrades.luau shared/Config/DeepFreeze.luau shared/Net/RateLimiter.luau client/Controllers/TrainingController.luau"
if [ -f "$SRC/shared/TrainingZone.luau" ]; then MODE=nouveau; else MODE=avant; fi
: "${R1_D:=$(d="${R1_RUN:-${TMPDIR:-/tmp}/r1-bancs}"; mkdir -p "$d" && mktemp -d "$d/b.XXXXXX")}" "${R1_D:?r1 : dossier du banc introuvable}"; OUT="$R1_D/run.luau"
{
	if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; else echo "VERBOSE = false"; fi
	echo "MODE = \"$MODE\""
	echo "SOURCES = {}"
	printf '%s\n' $FILES | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
	if [ "$MODE" = "avant" ]; then
		# Ancien arbre : pas de module TrainingZone ni de remote TrainLeave à charger.
		sed '/module("TrainingZone"/d' "$HARNESS"
	else
		cat "$HARNESS"
	fi
	cat "$H/ext.luau" "$H/tests.luau"
} > "$OUT"
out=$("$LUAU" "$(cygpath -w "$OUT")" 2>&1)
line=$(printf '%s\n' "$out" | grep -E "^banc a115 .*: [0-9]+ vérification\(s\), [0-9]+ échec\(s\)$" | tail -1)
if [ -z "$line" ]; then
	printf '%s\n' "$out" | tail -25
	echo "banc a115 : arrêté avant la fin (erreur ci-dessus) : 0 vérification(s), 1 échec(s)"
	exit 1
fi
if [ "${VERBOSE:-}" = "1" ]; then printf '%s\n' "$out"; else printf '%s\n' "$out" | grep -E "ÉCHEC|ERREUR|MESURE" || true; fi
echo "$line"
printf '%s' "$line" | grep -qE " 0 échec"
