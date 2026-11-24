#!/usr/bin/env bash
# Banc hors Studio d'a200 (2026-11-15, vague 61 ; Cantin) :
#   swap   tapis amélioré pendant la séance (MachineVariantService pose sa variante) : la séance continue, serveur et
#          client (TrainingMachine jamais retiré, TreadmillRun jamais arrêté, crédits au nouveau niveau, aucun
#          TrainLeave), replacé si le UsePoint bouge, retour au tapis de base (l'ancien part avant), règle d'a180
#          gardée pour une nouvelle montée, tapis retiré sans remplaçant : arrêt après SwapGrace.
#          Faux Roblox : harnais de la copie a134 d'a65 et côté client de la copie a134 d'a115 (lus sur place, comme
#          a180-banc) ; vrais TrainingService, TrainingController, MachineVariantService, Shared/TrainingZone…
#   chunk1 un seul « +X Speed/s » par seconde sur le tapis (Config/Hud.TreadmillGain.ChunksPerSecond = 1), même total,
#          une pulsation du compteur par seconde, exposant « ×2 » gardé (copie a200 du banc a190, scénario chunk1).
# Arbre sans Training.Treadmill.SwapGrace (avant a200) : « SAUTÉ ».
#   bash run.sh [racine du dépôt]   (défaut : /f/StealAShop)
#   VERBOSE=1 bash run.sh           écrit aussi les lignes ok
set -u
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop}"
ROOT="${ROOT%/src}"
SRC="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
if ! grep -q "SwapGrace" "$SRC/shared/Config/Training.luau" 2>/dev/null; then
	echo "banc a200 (tapis amélioré, 1 gain par seconde) : SAUTÉ, a200 pas encore fusionné : 0 vérification(s), 0 échec(s)"
	exit 0
fi
HARNESS="$H/../a134-banc/autres-bancs/a65/harness.luau"
EXT="$H/../a134-banc/autres-bancs/a115/ext.luau"
FILES="server/Services/TrainingService.luau shared/TrainingZone.luau server/Services/MachineVariantService.luau shared/Config/Training.luau shared/Config/Upgrades.luau shared/Config/DeepFreeze.luau shared/Net/RateLimiter.luau client/Controllers/TrainingController.luau"
: "${R1_D:=$(d="${R1_RUN:-${TMPDIR:-/tmp}/r1-bancs}"; mkdir -p "$d" && mktemp -d "$d/b.XXXXXX")}" "${R1_D:?r1 : dossier du banc introuvable}"; OUT="$R1_D/run.swap.luau"
{
	if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; else echo "VERBOSE = false"; fi
	echo "MODE = \"nouveau\""
	echo "SOURCES = {}"
	printf '%s\n' $FILES | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
	cat "$HARNESS" "$EXT" "$H/tests.swap.luau"
} > "$OUT"
out=$("$LUAU" "$(cygpath -w "$OUT")" 2>&1)
line=$(printf '%s\n' "$out" | grep -E "^banc a200 .*: [0-9]+ vérification\(s\), [0-9]+ échec\(s\)$" | tail -1)
checks=0
fails=0
if [ -z "$line" ]; then
	printf '%s\n' "$out" | tail -25
	echo "  swap : arrêté avant la fin (erreur ci-dessus)"
	fails=1
else
	if [ "${VERBOSE:-}" = "1" ]; then printf '%s\n' "$out"; else printf '%s\n' "$out" | grep -E "ÉCHEC|ERREUR" || true; fi
	c=$(printf '%s' "$line" | sed -E 's/.*: ([0-9]+) vérification.*/\1/')
	f=$(printf '%s' "$line" | sed -E 's/.*, ([0-9]+) échec.*/\1/')
	echo "  swap : $c contrôles, $f raté(s)"
	checks=$((checks + c))
	fails=$((fails + f))
fi
gain=$(bash "$H/autres-bancs/a190/run.sh" "$ROOT" chunk1 2>&1)
gline=$(printf '%s\n' "$gain" | grep -E "^banc a190 .*: [0-9]+ vérification\(s\), [0-9]+ échec\(s\)$" | tail -1)
if [ -z "$gline" ]; then
	printf '%s\n' "$gain" | tail -25
	echo "  chunk1 : arrêté avant la fin (erreur ci-dessus)"
	fails=$((fails + 1))
else
	printf '%s\n' "$gain" | grep -E "ÉCHEC|ERREUR" || true
	c=$(printf '%s' "$gline" | sed -E 's/.*: ([0-9]+) vérification.*/\1/')
	f=$(printf '%s' "$gline" | sed -E 's/.*, ([0-9]+) échec.*/\1/')
	echo "  chunk1 : $c contrôles, $f raté(s)"
	checks=$((checks + c))
	fails=$((fails + f))
fi
echo "banc a200 (tapis amélioré, 1 gain par seconde) : $checks vérification(s), $fails échec(s)"
exit $((fails > 0))
