#!/usr/bin/env bash
# Copie a134 (2026-11-14, vague 40, rééquilibrage v2 appliqué dans src/) : faux arbre du volet témoins complété (Config/Balance, Cosmetics, Tools : requis par Config/Zones).
# Arbre sans le rééquilibrage (Balance.Stats.WalkPerDecade absent) : le banc d'avant tourne tel quel.
_A134_R="${1:-/f/StealAShop}"; _A134_F="$_A134_R/src/shared/Config/Balance.luau"; [ -f "$_A134_F" ] || _A134_F="$_A134_R/shared/Config/Balance.luau"
if ! grep -q "WalkPerDecade" "$_A134_F" 2>/dev/null; then exec bash "$(cd "$(dirname "$0")" && pwd)/../../../a100-banc/run.sh" "$@"; fi
# Banc hors Studio d'a100 (vague 30, 2026-11-12, liaison L-111 : témoins et police).
#   witness/ : le vrai WitnessService sur un faux Roblox autonome (contrat, jauge, balade sur WitnessPaths, regard au
#              premier coup, « ? » vidé à la casse, appel au premier marqueur Call, policier demandé à GuardService,
#              choix du suspect, API de L-112 : Raise, Pause, Calm, GetFill, IsCalling, OnCall) ;
#   police/  : le policier dans le vrai GuardService (StartDriverChase avec Label, Tired, GiveUpReason ;
#              FindGuardModel, IsInSafeZone), sur le faux Roblox du banc a54-guard lu sur place.
#   bash run.sh [racine du dépôt]   (défaut : /f/StealAShop)
# Avant la fusion d'a100 : « SAUTÉ » (0 vérification).
set -u
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop}"
if [ ! -f "$ROOT/src/server/Services/WitnessService.luau" ]; then
	echo "banc a100 (témoins et police) : SAUTÉ, pas de WitnessService (a100 pas encore fusionné) : 0 vérification(s), 0 échec(s)"
	exit 0
fi
total=0; failed=0; broken=0
for part in witness police; do
	out=$(timeout 300 bash "$H/$part/run.sh" "$ROOT" 2>&1)
	printf '%s\n' "$out" | grep -E "ÉCHEC|ERREUR|rror|SAUTÉ" | sed "s/^/  $part /"
	line=$(printf '%s\n' "$out" | grep -E "[0-9]+ vérification\(s\), [0-9]+ échec\(s\)$" | tail -1)
	if [ -z "$line" ]; then echo "  $part : arrêté avant la fin"; printf '%s\n' "$out" | tail -8 | sed 's/^/    /'; broken=$((broken + 1)); continue; fi
	c=$(printf '%s' "$line" | sed -E 's/^.*[^0-9]([0-9]+) vérif.*/\1/; s/^([0-9]+) vérif.*/\1/'); f=$(printf '%s' "$line" | sed -E 's/.*, ([0-9]+) échec.*/\1/')
	echo "  $part : $c contrôles, $f raté(s)"
	total=$((total + c)); failed=$((failed + f))
done
failed=$((failed + broken))
echo "banc a100 (témoins et police) : $total vérification(s), $failed échec(s)"
exit $((failed > 0))
