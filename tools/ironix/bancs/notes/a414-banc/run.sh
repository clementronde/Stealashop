#!/usr/bin/env bash
# Banc a414 (vague GC7, 23/11) : entonnoirs FunnelService (Config/Funnels) hors Studio, faux Roblox minimal de bench.luau :
# Config (limites de Roblox, noms, étapes du client), FirstSteps (nouveau profil, Loaded avant le profil, LoadingTime),
# Progression (ancien profil, zones, renaissance), boutiques (sessions GUID, View/Buy/Bought seulement après Open),
# débit du client, vol chez un joueur (Enter, Grab, Exit, Deposit, sessions), interrupteur Features.Analytics.
# Arbre sans Config/Funnels (avant a414) : SAUTÉ.
#   bash run.sh [racine du dépôt]   (défaut : /f/StealAShop)
#   VERBOSE=1 bash run.sh            écrit aussi les lignes ok
set -u
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop}"
ROOT="${ROOT%/src}"
SRC="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
if [ ! -f "$SRC/shared/Config/Funnels.luau" ]; then
	echo "banc a414 (entonnoirs) : SAUTÉ (arbre sans Config/Funnels), 0 vérification(s), 0 échec(s)"
	exit 0
fi
FILES="shared/Config/DeepFreeze.luau shared/Config/Funnels.luau shared/Config/Telemetry.luau shared/Config/Features.luau shared/Contract/Find.luau server/Services/FunnelService.luau"
: "${R1_D:=$(d="${R1_RUN:-${TMPDIR:-/tmp}/r1-bancs}"; mkdir -p "$d" && mktemp -d "$d/b.XXXXXX")}" "${R1_D:?r1 : dossier du banc introuvable}"; OUT="$R1_D/run.a414.luau"
{
	if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; else echo "VERBOSE = false"; fi
	echo "SOURCES = {}"
	(cd "$SRC" && ls $FILES) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
	cat "$H/bench.luau"
} > "$OUT"
out=$("$LUAU" "$(cygpath -w "$OUT")" 2>&1)
line=$(printf '%s\n' "$out" | grep -E "^scénario a414 : [0-9]+ vérification\(s\), [0-9]+ échec\(s\)$" | tail -1)
if [ -z "$line" ]; then
	printf '%s\n' "$out" | tail -25
	echo "banc a414 (entonnoirs) : arrêté avant la fin (erreur ci-dessus), 0 vérification(s), 1 échec(s)"
	exit 1
fi
if [ "${VERBOSE:-}" = "1" ]; then printf '%s\n' "$out"; else printf '%s\n' "$out" | grep -E "ÉCHEC|ERREUR" || true; fi
c=$(printf '%s' "$line" | sed -E 's/.* : ([0-9]+) vérification.*/\1/')
f=$(printf '%s' "$line" | sed -E 's/.*, ([0-9]+) échec.*/\1/')
echo "banc a414 (entonnoirs) : $c vérification(s), $f échec(s)"
exit $((f > 0))
