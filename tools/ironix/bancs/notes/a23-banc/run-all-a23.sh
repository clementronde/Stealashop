#!/usr/bin/env bash
# Variante de run-all-bancs.sh préparée par a23 (2026-11-07, ouverture des colis v2) : mêmes bancs,
# avec les copies à jour d'a13 et a15 (a23-banc/autres-bancs) et le banc a23 en plus. À utiliser
# après la fusion de la branche agent/a23-ouverture (les copies attendent UnboxReveal v2).
#   bash a23-banc/run-all-a23.sh [racine du dépôt]   (défaut : /f/StealAShop)
#   DETAIL=1 bash a23-banc/run-all-a23.sh            écrit aussi les lignes d'échec et d'erreur
#
# Bancs remis à jour le 2026-11-07 : a08 (Color3.fromHex, Config/Shatter, noms d'outils en anglais),
# a09 (14 animations), a13 (CFrame:ToObjectSpace, textes en anglais), a14 (textes et nombres du HUD),
# a16 (SMASHED!), copie a12 d'a21 (PhysicsService, CollisionGroup). Pour a06, a12, a15 et le braquage
# d'a17, ce sont les copies à jour d'a21 qui tournent (a21-banc/autres-bancs). a10 et a11 ne sont plus
# lancés : a17-heist reprend les scénarios d'a10 (tests.a10.luau), a17-carry ceux d'a11.
set -u
H="$(cd "$(dirname "$0")/.." && pwd)"
REPO="${1:-/f/StealAShop}"
SRC="$REPO/src"
A="$H/a21-banc/autres-bancs"
# nom:script:argument (racine du dépôt ou racine src, selon le banc)
BANCS=(
	"a06:$A/a06-tests/run.sh:$REPO"
	"a08:$H/a08-harness/run.sh:$SRC"
	"a09:$H/a09-banc-hors-studio/run.sh:$REPO"
	"a12:$A/a12-harness/run.sh:$SRC"
	"a13:$H/a23-banc/autres-bancs/a13-banc/run.sh:$REPO"
	"a14:$H/a14-banc/run.sh:$REPO"
	"a15:$H/a23-banc/autres-bancs/a15-banc/run.sh:$REPO"
	"a16:$H/a16-banc/run.sh:$REPO"
	"a17-carry:$H/a17-banc/carry/run.sh:$REPO"
	"a17-heist:$A/a17-banc/heist/run.sh:$SRC"
	"a17-shelf:$H/a17-banc/shelf/run.sh:$REPO"
	"a19:$H/a19-banc/run.sh:$REPO"
	"a20:$H/a20-banc/run.sh:$REPO"
	"a21-night:$H/a21-banc/night/run.sh:$REPO"
	"a21-hud:$H/a21-banc/hud/run.sh:$REPO"
	"a23:$H/a23-banc/run.sh:$REPO"
)
total_fail=0
for entry in "${BANCS[@]}"; do
	name="${entry%%:*}"; rest="${entry#*:}"; script="${rest%%:*}"; arg="${rest#*:}"
	out=$(timeout 240 bash "$script" "$arg" 2>&1)
	summary=$(printf '%s\n' "$out" | grep -E "vérification\(s\)|réussi\(s\)" | tr '\n' ' ' | cut -c1-160)
	printf '%-10s %s\n' "$name" "${summary:-PAS DE RÉSUMÉ}"
	if [ -z "$summary" ] || printf '%s\n' "$summary" | grep -qE "[1-9][0-9]* échec"; then total_fail=$((total_fail + 1)); fi
	if [ "${DETAIL:-}" = "1" ]; then
		printf '%s\n' "$out" | grep -E "ÉCHEC|ERREUR" | head -12 | sed 's/^/    /'
	fi
done
echo "bancs en échec : $total_fail"
exit $((total_fail > 0))
