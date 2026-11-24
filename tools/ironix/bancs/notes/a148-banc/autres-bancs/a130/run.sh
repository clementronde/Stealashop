#!/usr/bin/env bash
# Copie a148 (2026-11-14, vague 42) : Features.FortuneTower = true livré ; tests.prodoff.luau coupe l'interrupteur à la
# main (setFeature) pour garder « Force refusé hors Studio, coupé ». Arbre sans a148 (FortuneTower.LootZones absent) :
# la copie a134 tourne telle quelle.
_A148_R="${1:-/f/StealAShop}"; _A148_F="$_A148_R/src/shared/Config/FortuneTower.luau"
if [ -f "$_A148_F" ] && ! grep -q "LootZones" "$_A148_F" 2>/dev/null; then exec bash "$(cd "$(dirname "$0")" && pwd)/../../../a134-banc/autres-bancs/a130/run.sh" "$@"; fi
# Copie a134 (2026-11-14, vague 40, rééquilibrage v2 appliqué dans src/) : faux arbre du volet admin complété (Config/Tools), harnais de la copie a134 d'a98.
# Arbre sans le rééquilibrage (Balance.Stats.WalkPerDecade absent) : le banc d'avant tourne tel quel.
_A134_R="${1:-/f/StealAShop}"; _A134_F="$_A134_R/src/shared/Config/Balance.luau"; [ -f "$_A134_F" ] || _A134_F="$_A134_R/shared/Config/Balance.luau"
if ! grep -q "WalkPerDecade" "$_A134_F" 2>/dev/null; then exec bash "$(cd "$(dirname "$0")" && pwd)/../../../a130-banc/run.sh" "$@"; fi
# Banc hors Studio d'a130 (vague 39, 2026-11-14) : suites de la Fortune Tower et vendeurs des comptoirs.
#   admin   : StartEvent Fortune / FortuneOpen / FortuneSeal, Truck refusé pendant une vitrine (harnais du banc a98)
#   fortune : FortuneTowerService.Force, pas de camion tant qu'une vitrine est en jeu (assemblage du banc a123)
#   telem   : BatBoxKnockdown Source Store / Truck / Fortune (mise en place de la copie a126 du banc a35)
#   vendor  : VendorService, Idle et Wave, sans animations rien (faux Roblox à lui)
# Chaque partie dit « SAUTÉ » sur un arbre sans a130.
#   bash run.sh [racine du dépôt]   (défaut : /f/StealAShop)
set -u
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop}"
checks=0
fails=0
for part in admin fortune telem vendor; do
	out=$(bash "$H/run-$part.sh" "$ROOT" 2>&1)
	printf '%s\n' "$out" | grep -E "ÉCHEC|ERREUR|arrêté|SAUTÉ" || true
	line=$(printf '%s\n' "$out" | grep -E "[0-9]+ vérification\(s\), [0-9]+ échec\(s\)$" | tail -1)
	if [ -z "$line" ]; then
		fails=$((fails + 1))
		continue
	fi
	c=$(printf '%s' "$line" | sed -E 's/.* ([0-9]+) vérification.*/\1/')
	f=$(printf '%s' "$line" | sed -E 's/.*, ([0-9]+) échec.*/\1/')
	checks=$((checks + c))
	fails=$((fails + f))
done
echo "banc a130 (Fortune Tower, vendeurs) : $checks vérification(s), $fails échec(s)"
exit $((fails > 0))
