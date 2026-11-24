#!/usr/bin/env bash
# a302 (21/11, Cantin : bulles deux fois moins souvent, SpawnMin = 4 et SpawnMax = 6) : copie du banc a214 ; les durées
# simulées et les attentes lisent Bubbles.SpawnMin, SpawnMax, MaxAtOnce et Lifetime ; D7 attend 4, 6, 2 et 6. Arbre
# encore à SpawnMin = 2 : le banc a214 d avant tel quel.
# Banc hors Studio d'a214 (vague 64, Cantin 16/11 : les bulles ×N du tapis ; BubbleService, Config/Bubbles,
# TrainingService.IsTraining et GainPerSecond). Faux Roblox : harnais de la copie a134 du banc a65 (lu sur place, comme
# a200-banc), règle d'a180 allumée ; vrais TrainingService, Shared/TrainingZone, MachineVariantService, Config/Training,
# Config/Bubbles, BubbleService.
#   draw    tirage : Draw aux bornes, fréquences sur 100 000 tirages ≈ table de Cantin, valeurs de Config/Bubbles
#   rhythm  rien hors du tapis ; première bulle entre SpawnMin et SpawnMax s ; jamais plus de MaxAtOnce ; « Expired » à Lifetime s pile
#   claim   gain = 1 s de tapis × N (niveau et boost compris), versé par StatsService, une seule fois ; tapis inchangé ;
#           par le remote ClaimBubble aussi
#   refuse  bulle d'un autre, débit (ClaimMinGap), id inconnu, expirée, plus en séance
#   leave   descendre du tapis retire tout (« Cleared »), rien hors du tapis, le compte repart ; départ du joueur
# Arbre sans Config/Bubbles (avant a214) : « SAUTÉ ».
#   bash run.sh [racine du dépôt] [scénarios séparés par des virgules]   VERBOSE=1 : lignes ok
set -u
H="$(cd "$(dirname "$0")" && pwd)"
B="$(cd "$H/../../.." && pwd)"
ROOT="${1:-/f/StealAShop}"
ROOT="${ROOT%/src}"
if grep -qE "^[[:space:]]*SpawnMin = 2," "$ROOT/src/shared/Config/Bubbles.luau" 2>/dev/null; then
	exec bash "$B/a214-banc/run.sh" "$@"
fi
SRC="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
LABEL="banc a214 (bulles ×N)"
if [ ! -f "$SRC/shared/Config/Bubbles.luau" ]; then
	echo "$LABEL : SAUTÉ, a214 pas encore fusionné : 0 vérification(s), 0 échec(s)"
	exit 0
fi
HARNESS="$B/a134-banc/autres-bancs/a65/harness.luau"
FILES="server/Services/TrainingService.luau shared/TrainingZone.luau server/Services/MachineVariantService.luau shared/Config/Training.luau shared/Config/Upgrades.luau shared/Config/DeepFreeze.luau shared/Net/RateLimiter.luau shared/Config/Bubbles.luau server/Services/BubbleService.luau"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
OUT="$TMP/run.bubbles.luau"
{
	if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; else echo "VERBOSE = false"; fi
	if [ -n "${2:-}" ]; then echo "SCENARIO = \"$2\""; fi
	echo "SOURCES = {}"
	printf '%s\n' $FILES | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
	cat "$HARNESS" "$H/tests.bubbles.luau"
} > "$OUT"
out=$("$LUAU" "$(cygpath -w "$OUT")" 2>&1)
line=$(printf '%s\n' "$out" | grep -E "^banc a214 .*: [0-9]+ vérification\(s\), [0-9]+ échec\(s\)$" | tail -1)
if [ -z "$line" ]; then
	printf '%s\n' "$out" | tail -25
	echo "$LABEL : arrêté avant la fin (erreur ci-dessus) : 0 vérification(s), 1 échec(s)"
	exit 1
fi
if [ "${VERBOSE:-}" = "1" ]; then printf '%s\n' "$out"; else printf '%s\n' "$out" | grep -E "ÉCHEC|ERREUR" || true; fi
echo "$line"
printf '%s' "$line" | grep -qE " 0 échec"
