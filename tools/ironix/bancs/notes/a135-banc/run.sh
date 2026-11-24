#!/usr/bin/env bash
# Banc hors Studio d'a135 (vague 40, 2026-11-14, rééquilibrage v2 de Cantin) : braquage, police, profils.
#   heist    serveur (faux Roblox et mise en place d'a114) : chrono de police au premier coup (police = true, 13 s),
#            masqué à la casse, chrono HEIST de Balance.Heist.Duration (6 s) à partir de la casse, fin à casse + 6 s ;
#            pas cassée à temps : PV max, « Too slow! », chrono masqué (comportement gardé)
#   hud      client (faux Roblox d'a21-hud) : « POLICE IN 13s » puis « HEIST: 6s » dans UI_HUD.HeistTimer
#   profiles DataService : jeu DEV → Balance.Profiles.DevStoreName ; PROD et autres → « PlayerData » ; rien d'effacé
# Chaque partie dit « SAUTÉ » sur un arbre sans a135.
#   bash run.sh [racine du dépôt]   (défaut : /f/StealAShop)
set -u
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop}"
checks=0
fails=0
for part in heist hud profiles; do
	out=$(bash "$H/run-$part.sh" "$ROOT" 2>&1)
	printf '%s\n' "$out" | grep -E "ÉCHEC|ERREUR|rror|SAUTÉ" || true
	line=$(printf '%s\n' "$out" | grep -E "[0-9]+ vérification\(s\), [0-9]+ échec\(s\)$" | tail -1)
	if [ -z "$line" ]; then
		printf '%s\n' "$out" | tail -10
		fails=$((fails + 1))
		continue
	fi
	c=$(printf '%s' "$line" | sed -E 's/^(.* )?([0-9]+) vérification.*/\2/')
	f=$(printf '%s' "$line" | sed -E 's/.*, ([0-9]+) échec.*/\1/')
	checks=$((checks + c))
	fails=$((fails + f))
done
echo "banc a135 (braquage, police, profils) : $checks vérification(s), $fails échec(s)"
exit $((fails > 0))
