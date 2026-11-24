#!/usr/bin/env bash
# a412 (23/11) : copie de a226-banc/run.sh ; le bandeau de zone écrit « Strength 2M ×2 players » (AdvicePanel.strengthText, L-108, L-110 ; damageText retiré). tests.luau lu dans a226-banc.
# Banc hors Studio d'a226 (vague 68) : marche des dégâts du panneau lissée (1, 10, 300, 10K, 320K, 2M), prix des kits pour
# des temps entre zones qui s'allongent (zone 6 vers 7 h 30, simulateur v2), Spark, Shine et Dust à 100 $, dernière zone
# « ×2 players » (AdvicePanel, ZoneBannerController).
#   1. tests.luau : vraies tables de src/shared/Config (dégâts, PV, casse seul et à deux, prix croissants, migration des
#      auras, don du tuto), égalité avec tools/ironix/equilibrage/proposition_v2.luau ;
#   2. contrôles du code source du panneau.
# « SAUTÉ » sur un arbre sans a226 (pas de teamSuffix dans AdvicePanel).
#   bash run.sh [racine du dépôt]   (défaut : /f/StealAShop)
set -u
H="$(cd "$(dirname "$0")/../../../a226-banc" && pwd)"
ROOT="${1:-/f/StealAShop}"
ROOT="${ROOT%/src}"
SRC="$ROOT/src"
LUAU="${LUAU:-$HOME/.rokit/bin/luau.exe}"
if ! grep -q "teamSuffix" "$SRC/shared/AdvicePanel.luau" 2>/dev/null; then
	echo "banc a226 (marche des dégâts) : SAUTÉ (arbre sans a226) : 0 vérification(s), 0 échec(s)"
	exit 0
fi
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
OUT="$TMP/a226.luau"
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
	if [ -f "$SRC/shared/ItemWeight.luau" ]; then emit "ItemWeight" "$SRC/shared/ItemWeight.luau"; fi
	for m in proposition_v2 modele; do
		emit "Outil/$m" "$T/$m.luau"
	done
	tr -d '\r' < "$T/chargeur.luau" | grep -v '^charge(if OPTIONS'
	tr -d '\r' < "$H/tests.luau"
} > "$OUT"
out=$("$LUAU" "$(cygpath -w "$OUT")" 2>&1)
printf '%s\n' "$out" | grep -E "ÉCHEC|rror|^note|^parties" || true
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
present() {
	checks=$((checks + 1))
	if ! grep -qE "$1" "$SRC/$2"; then
		fails=$((fails + 1))
		echo "ÉCHEC : $2 ne contient pas « $1 »"
	fi
}
present 'TEAM_TEXT = " ×%d players"' shared/AdvicePanel.luau
present 'Format\.short\(zone\.AdvisedDamage\)\) \.\. teamSuffix\(zone\)' shared/AdvicePanel.luau
present 'zone\.AdvisedDamage \* teamSize\(zone\)' shared/AdvicePanel.luau
present 'Balance\.WindowHP\.LastZoneTeamSize' shared/AdvicePanel.luau
present 'damage\.Text = AdvicePanel\.strengthText\(zone\)' client/Controllers/ZoneBannerController.luau
present 'AdvicePanel\.strengthText\(zone\)' client/Controllers/StoreInfoController.luau
present 'AdvicePanel\.strengthText\(zone\)' client/Controllers/StoreReqSignController.luau
echo "banc a226 (marche des dégâts, prix, panneau « ×2 players ») : $checks vérification(s), $fails échec(s)"
exit $((fails > 0))
