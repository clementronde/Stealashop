#!/usr/bin/env bash
# Banc hors Studio d'a134 (vague 40, 2026-11-14) : rééquilibrage v2, passe 2, appliqué dans src/.
#   1. tests.luau : les vraies tables et formules de src/shared/Config (dégâts, marche, tapis, PV des vitrines,
#      casse seul et à deux, plafond de coups de Net, potions, portes, camion, Fortune Tower) et l'égalité avec
#      tools/ironix/equilibrage/proposition_v2.luau (chargeur du simulateur) ;
#   2. contrôles du code source : plus de banc, plus de Force, plus de potion de vitesse, HUD, cadence du client.
# « SAUTÉ » sur un arbre sans le rééquilibrage (Balance.Stats.WalkPerDecade absent).
#   bash run.sh [racine du dépôt]   (défaut : /f/StealAShop)
set -u
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop}"
SRC="$ROOT/src"
LUAU="${LUAU:-$HOME/.rokit/bin/luau.exe}"
if ! grep -q "WalkPerDecade" "$SRC/shared/Config/Balance.luau"; then
	echo "banc a134 (rééquilibrage v2) : SAUTÉ (arbre sans le rééquilibrage) : 0 vérification(s), 0 échec(s)"
	exit 0
fi
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
OUT="$TMP/a134.luau"
emit() {
	awk -v key="$1" '{ sub(/\r$/, ""); lines = lines $0 "\n" } END { printf "SOURCES[\"%s\"] = [==========[\n%s]==========]\n", key, lines }' "$2"
}
T="$ROOT/tools/ironix/equilibrage"
{
	echo "--!nocheck"
	echo "SOURCES = {}"
	echo 'OPTIONS = { Graines = 1, Heures = 1, Rapport = "v2", Court = true }'
	for f in "$SRC"/shared/Config/*.luau; do
		emit "Config/$(basename "$f" .luau)" "$f"
	done
	emit "Format" "$SRC/shared/Format.luau"
	emit "Net/Definitions" "$SRC/shared/Net/Definitions.luau"
	emit "Net/RateLimiter" "$SRC/shared/Net/RateLimiter.luau"
	for m in proposition_v2 modele; do
		emit "Outil/$m" "$T/$m.luau"
	done
	# Le chargeur du simulateur, sans sa dernière ligne (qui lance un rapport).
	tr -d '\r' < "$T/chargeur.luau" | grep -v '^charge(if OPTIONS'
	tr -d '\r' < "$H/tests.luau"
} > "$OUT"
out=$("$LUAU" "$(cygpath -w "$OUT")" 2>&1)
printf '%s\n' "$out" | grep -E "ÉCHEC|rror" || true
line=$(printf '%s\n' "$out" | grep -E "[0-9]+ vérification\(s\), [0-9]+ échec\(s\)$" | tail -1)
checks=0
fails=0
if [ -z "$line" ]; then
	echo "ERREUR : tests.luau n'a pas fini"
	printf '%s\n' "$out" | tail -5
	fails=1
else
	checks=$(printf '%s' "$line" | sed -E 's/.* ([0-9]+) vérification.*/\1/')
	fails=$(printf '%s' "$line" | sed -E 's/.*, ([0-9]+) échec.*/\1/')
fi
# Contrôles du code source : absent "motif" fichier / present "motif" fichier.
absent() {
	checks=$((checks + 1))
	if grep -qE "$1" "$SRC/$2"; then
		fails=$((fails + 1))
		echo "ÉCHEC : $2 contient encore « $1 »"
	fi
}
present() {
	checks=$((checks + 1))
	if ! grep -qE "$1" "$SRC/$2"; then
		fails=$((fails + 1))
		echo "ÉCHEC : $2 ne contient pas « $1 »"
	fi
}
checks=$((checks + 1))
if [ -e "$SRC/client/Controllers/BenchBarController.luau" ]; then
	fails=$((fails + 1))
	echo "ÉCHEC : BenchBarController.luau existe encore"
fi
absent 'watchTag\(BENCH_TAG|"Bench"\)|AddStrength|benchRep|BenchUserId' server/Services/TrainingService.luau
present 'Formulas\.TreadmillGain\(level\) \* gainMultiplier' server/Services/TrainingService.luau
present 'TREADMILL_TICK \* treadmillGain\(player\) \* bonus' server/Services/TrainingService.luau
absent 'function StatsService\.(Add|Get)Strength|data\.Stats\.Strength' server/Services/StatsService.luau
present 'SetAttribute\("ShownSpeed", Formulas\.ShownSpeed\(data\.Stats\.Speed, trail\)\)' server/Services/StatsService.luau
present 'Formulas\.HitDamage\(equippedDef\(data\)\.Power, auraMultiplier\(player\)\)' server/Services/ToolService.luau
absent 'Stats\.Strength|STRENGTH_ATTRIBUTE' server/Services/ToolService.luau
absent 'SetSpeedModifier|SPEED_KEY|== "Speed"' server/Services/PotionService.luau
present 'baseDamage\(player\) \* multiplierOf\(player, "Strength"\)' server/Services/PotionService.luau
present 'ToolService\.GetHitDamage\(player\)' server/Services/WindowService.luau
present 'TruckEvent\.HPPerDamage \* zoneInfo\.AdvisedDamage' server/Services/TruckEventService.luau
absent 'handlers\.(GiveStrength|SetBench)' server/Services/AdminService.luau
absent 'GiveStrength|SetBench' shared/Config/Admin.luau
absent 'BENCH_TAG|"Bench"' server/Services/TutorialService.luau
present 'Formulas\.TreadmillShownLevel\(level\)' server/Services/MachineVariantService.luau
present 'Attribute = "ShownSpeed", Element = "Speed"' client/Controllers/HudController.luau
present 'Attribute = "Damage", Element = "Strength"' client/Controllers/HudController.luau
absent 'Attribute = "Strength"' client/Controllers/GainController.luau
absent 'id = "Bench"' client/Controllers/UpgradeController.luau
absent '== "Bench"|BENCH_' client/Controllers/TrainingController.luau
absent 'PlayPlayer\("Bench' client/Controllers/AnimationController.luau
present 'MIN_INTERVAL = 1 / Balance\.Hit\.MaxHitsPerSecond' client/Controllers/HitController.luau
present 'queuedClick = true' client/Controllers/HitController.luau
absent 'Name = "Bench(Lift|Idle)"' shared/Contract/Animations.luau
absent 'Tag = "Bench", Count' shared/Contract/Tags.luau
present 'SpeedAttribute = "ShownSpeed"' shared/AdvicePanel.luau
present 'zone\.SpeedRequired' shared/AdvicePanel.luau
echo "banc a134 (rééquilibrage v2 : Config, formules, plafond de coups, code sans banc) : $checks vérification(s), $fails échec(s)"
exit $((fails > 0))
