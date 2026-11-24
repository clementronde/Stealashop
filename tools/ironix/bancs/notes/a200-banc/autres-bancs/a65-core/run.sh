#!/usr/bin/env bash
# Copie a200 (2026-11-15, vague 61) : V3 mis à la nouvelle règle (tapis amélioré pendant la séance : la séance continue, plus de descente ni de remise) ; le reste tel quel.
# Copie a134 (2026-11-14, vague 40, rééquilibrage v2 appliqué dans src/) : plus de banc (Z3), gain du tapis 2^(niveau affiché − 1), variante du tapis lue sur le niveau affiché ; faux Formulas complété (TreadmillShownLevel, TreadmillGain).
# Arbre sans le rééquilibrage (Balance.Stats.WalkPerDecade absent) : le banc d'avant tourne tel quel.
_A134_R="${1:-/f/StealAShop}"; _A134_F="$_A134_R/src/shared/Config/Balance.luau"; [ -f "$_A134_F" ] || _A134_F="$_A134_R/shared/Config/Balance.luau"
if ! grep -q "WalkPerDecade" "$_A134_F" 2>/dev/null; then exec bash "$(cd "$(dirname "$0")" && pwd)/../../../a115-banc/autres-bancs/a65-banc/run.sh" "$@"; fi
# Copie a115 (2026-11-13) : tests Z1, Z2 et Z5 mis à la nouvelle règle (montée sans attente, tapis figé, cœur de la
# machine pour remonter, TrainLeave) ; harnais : Shared/TrainingZone et remote TrainLeave ajoutés.
# Banc hors Studio d'a65 (vague 22, 2026-11-11, L-093 points 1 et 3) : tapis et banc par leur zone, sans
# invite ; variantes du tapis selon son niveau. Faux Roblox autonome (harness.luau, repris d'a58) ;
# vrais : TrainingService, MachineVariantService, Config/Training, Config/Upgrades, Config/DeepFreeze,
# Net/RateLimiter. Bouchons : Formulas, Net, DataService, StatsService, AntiCheatService, PlotService.
#   bash run.sh [racine du dépôt]   (défaut : le worktree a65 ; après fusion : /f/StealAShop)
#   VERBOSE=1 bash run.sh           écrit aussi les lignes ok et la sortie des services
set -u
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop}"
SRC="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
if [ ! -f "$SRC/server/Services/MachineVariantService.luau" ]; then
	echo "banc a65 (zones des machines, variantes du tapis) : SAUTÉ, pas de MachineVariantService (a65 pas encore fusionné) : 0 vérification(s), 0 échec(s)"
	exit 0
fi
FILES="server/Services/TrainingService.luau shared/TrainingZone.luau server/Services/MachineVariantService.luau shared/Config/Training.luau shared/Config/Upgrades.luau shared/Config/DeepFreeze.luau shared/Net/RateLimiter.luau"
: "${R1_D:=$(d="${R1_RUN:-${TMPDIR:-/tmp}/r1-bancs}"; mkdir -p "$d" && mktemp -d "$d/b.XXXXXX")}" "${R1_D:?r1 : dossier du banc introuvable}"; OUT="$R1_D/run.luau"
{
	if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; else echo "VERBOSE = false"; fi
	echo "SOURCES = {}"
	printf '%s\n' $FILES | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
	cat "$H/harness.luau" "$H/tests.luau"
} > "$OUT"
out=$("$LUAU" "$(cygpath -w "$OUT")" 2>&1)
line=$(printf '%s\n' "$out" | grep -E "^banc a65 : [0-9]+ vérification\(s\), [0-9]+ échec\(s\)$" | tail -1)
if [ -z "$line" ]; then
	printf '%s\n' "$out" | tail -25
	echo "banc a65 : arrêté avant la fin (erreur ci-dessus) : 0 vérification(s), 1 échec(s)"
	exit 1
fi
if [ "${VERBOSE:-}" = "1" ]; then printf '%s\n' "$out"; else printf '%s\n' "$out" | grep -E "ÉCHEC|ERREUR" || true; fi
echo "$line"
printf '%s' "$line" | grep -qE " 0 échec"
