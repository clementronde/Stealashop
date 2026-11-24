#!/usr/bin/env bash
# a310 (22/11) : copie du lanceur a205-banc/run.tapis.sh ; harnais lus dans a134-banc, tests.tapis.luau d ici (cœur = emprise élargie).
# Banc a205 (vague 63, L-207 : tapis élargis ×1,5) : copie du lanceur d a180 (harnais a134 d a65 et a115 lus sur place), tests.tapis.luau d ici.
# passer devant ou derrière, même sur le bout de la bande, ne déclenche rien). Faux Roblox : harnais de la copie
# a134 d'a65 et côté client de la copie a134 d'a115 (lus sur place) ; vrais TrainingService, TrainingController,
# Shared/TrainingZone, Config/Training… Serveur et client vérifiés ensemble à chaque scénario.
# Arbre sans Training.Treadmill.SideEntryOnly (avant a180) : « SAUTÉ ».
#   bash run.sh [racine du dépôt]   (défaut : /f/StealAShop)
#   VERBOSE=1 bash run.sh           écrit aussi les lignes ok
set -u
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop}"
ROOT="${ROOT%/src}"
SRC="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
if ! grep -q "SideEntryOnly = true" "$SRC/shared/Config/Training.luau" 2>/dev/null; then
	echo "banc a180 (tapis par le côté) : SAUTÉ, pas de Training.Treadmill.SideEntryOnly (a180 pas encore fusionné) : 0 vérification(s), 0 échec(s)"
	exit 0
fi
HARNESS="$H/../../../a134-banc/autres-bancs/a65/harness.luau"
EXT="$H/../../../a134-banc/autres-bancs/a115/ext.luau"
FILES="server/Services/TrainingService.luau shared/TrainingZone.luau server/Services/MachineVariantService.luau shared/Config/Training.luau shared/Config/Upgrades.luau shared/Config/DeepFreeze.luau shared/Net/RateLimiter.luau client/Controllers/TrainingController.luau"
: "${R1_D:=$(d="${R1_RUN:-${TMPDIR:-/tmp}/r1-bancs}"; mkdir -p "$d" && mktemp -d "$d/b.XXXXXX")}" "${R1_D:?r1 : dossier du banc introuvable}"; OUT="$R1_D/run.tapis.luau"
{
	if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; else echo "VERBOSE = false"; fi
	echo "MODE = \"nouveau\""
	echo "SOURCES = {}"
	printf '%s\n' $FILES | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
	cat "$HARNESS" "$EXT" "$H/tests.tapis.luau"
} > "$OUT"
out=$("$LUAU" "$(cygpath -w "$OUT")" 2>&1)
line=$(printf '%s\n' "$out" | grep -E "^banc a205 tapis .*: [0-9]+ vérification\(s\), [0-9]+ échec\(s\)$" | tail -1)
if [ -z "$line" ]; then
	printf '%s\n' "$out" | tail -25
	echo "banc a205 tapis : arrêté avant la fin (erreur ci-dessus) : 0 vérification(s), 1 échec(s)"
	exit 1
fi
if [ "${VERBOSE:-}" = "1" ]; then printf '%s\n' "$out"; else printf '%s\n' "$out" | grep -E "ÉCHEC|ERREUR" || true; fi
echo "$line"
printf '%s' "$line" | grep -qE " 0 échec"
