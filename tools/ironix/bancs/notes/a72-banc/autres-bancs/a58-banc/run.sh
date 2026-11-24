#!/usr/bin/env bash
# Copie d'a72 (vague 24, 2026-11-11, L-091 point 2) : la barre n'est plus soudée à RightHand ; le serveur l'ancre,
# coupe ses collisions et pose BenchUserId sur le banc, les clients la placent (BenchBarController). Tests 4, 5,
# 6 et 8 adaptés. Sur un arbre sans BENCH_USER_ATTRIBUTE dans TrainingService, relance la copie d'a65 : bonne avant
# et après la fusion.
# Copie d'a65 (vague 22, 2026-11-11, L-093) : banc sans invite, entrée par sa zone (harness : sit et
# GetBoundingBox ; tests : getOff). Sur un arbre sans UseZone dans TrainingService, relance l'original
# d'a58 : bonne avant et après la fusion.
# Banc hors Studio d'a58 (vague 21, 2026-11-10, L-091 point 2) : banc d'entraînement automatique et barre
# qui suit les mains. Faux Roblox minimal et autonome (harness.luau) ; vrais : TrainingService,
# Config/Training, Config/DeepFreeze, Net/RateLimiter. Bouchons : Formulas, Upgrades, Net, DataService,
# StatsService, AntiCheatService.
#   bash run.sh [racine du dépôt]   (défaut : le worktree a58 ; après fusion : /f/StealAShop)
#   VERBOSE=1 bash run.sh           écrit aussi les lignes ok et la sortie du service
set -u
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop/agents/a65}"
SRC="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
if ! grep -q "BENCH_USER_ATTRIBUTE" "$SRC/server/Services/TrainingService.luau" 2>/dev/null; then
	exec bash "$H/../../../a65-banc/autres-bancs/a58-banc/run.sh" "$ROOT"
fi
if ! grep -q "USE_ZONE" "$SRC/server/Services/TrainingService.luau" 2>/dev/null; then
	exec bash "$H/../../../a58-banc/run.sh" "$ROOT"
fi
if ! grep -q "BENCH_AUTO_INTERVAL" "$SRC/server/Services/TrainingService.luau" 2>/dev/null; then
	echo "banc a58 (banc automatique, barre) : SAUTÉ, TrainingService sans banc automatique (a58 pas encore fusionné) : 0 vérification(s), 0 échec(s)"
	exit 0
fi
FILES="server/Services/TrainingService.luau shared/Config/Training.luau shared/Config/DeepFreeze.luau shared/Net/RateLimiter.luau"
: "${R1_D:=$(d="${R1_RUN:-${TMPDIR:-/tmp}/r1-bancs}"; mkdir -p "$d" && mktemp -d "$d/b.XXXXXX")}" "${R1_D:?r1 : dossier du banc introuvable}"; OUT="$R1_D/run.luau"
{
	if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; else echo "VERBOSE = false"; fi
	echo "SOURCES = {}"
	printf '%s\n' $FILES | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
	cat "$H/harness.luau" "$H/tests.luau"
} > "$OUT"
out=$("$LUAU" "$(cygpath -w "$OUT")" 2>&1)
line=$(printf '%s\n' "$out" | grep -E "^banc a58 : [0-9]+ vérification\(s\), [0-9]+ échec\(s\)$" | tail -1)
if [ -z "$line" ]; then
	printf '%s\n' "$out" | tail -25
	echo "banc a58 : arrêté avant la fin (erreur ci-dessus) : 0 vérification(s), 1 échec(s)"
	exit 1
fi
if [ "${VERBOSE:-}" = "1" ]; then printf '%s\n' "$out"; else printf '%s\n' "$out" | grep -E "ÉCHEC|ERREUR" || true; fi
echo "$line"
printf '%s' "$line" | grep -qE " 0 échec" 
