#!/usr/bin/env bash
# Banc hors Studio d'a111 (2026-11-13, vague 33, demande de Cantin : une potion ramassée va dans l'inventaire,
# le joueur la boit quand il veut). Deux parties :
#   - serveur, scénario stock (tests.stock.luau) sur la copie a111 du banc a88 (autres-bancs/a88-banc : mêmes
#     faux Roblox, PotionService réel) : profil sans potions, profil abîmé nettoyé, ramassage → stock, plafond,
#     UsePotion → effet (cumul), refus, mort, clear, débit ;
#   - client, scénario potions (tests.potions.luau) sur le banc a61 de l'inventaire (copie a62, lue sur place) :
#     section Potions de UI_Inventory, cartes V0 sur le Template de ToolsSection, UsePotion au clic.
#   bash run.sh [racine du dépôt]   (défaut : /f/StealAShop)
# Avant la vague 33 (pas de remote UsePotion) : « SAUTÉ » (0 vérification).
set -u
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop}"
if ! grep -q "\"UsePotion\"" "$ROOT/src/shared/Net/Definitions.luau" 2>/dev/null; then
	echo "banc a111 SAUTÉ : cet arbre n'a pas encore UsePotion"
	echo "banc a111 (inventaire des potions) : 0 vérification(s), 0 échec(s)"
	exit 0
fi
checks=0
fails=0
out=$(TESTS_DIR="$H" BANC_LABEL="serveur" bash "$H/autres-bancs/a88-banc/run.sh" "$ROOT" stock 2>&1)
printf '%s\n' "$out" | grep -vE "^serveur : " || true
line=$(printf '%s\n' "$out" | grep -E "^serveur : [0-9]+ vérification" | tail -1)
if [ -z "$line" ]; then
	fails=$((fails + 1))
else
	checks=$((checks + $(printf '%s' "$line" | sed -E 's/.* : ([0-9]+) vérification.*/\1/')))
	fails=$((fails + $(printf '%s' "$line" | sed -E 's/.*, ([0-9]+) échec.*/\1/')))
fi
if [ -f "$H/client.sh" ]; then
	out=$(bash "$H/client.sh" "$ROOT" 2>&1)
	printf '%s\n' "$out" | grep -vE "^client : " || true
	line=$(printf '%s\n' "$out" | grep -E "^client : [0-9]+ vérification" | tail -1)
	if [ -z "$line" ]; then
		fails=$((fails + 1))
	else
		checks=$((checks + $(printf '%s' "$line" | sed -E 's/.* : ([0-9]+) vérification.*/\1/')))
		fails=$((fails + $(printf '%s' "$line" | sed -E 's/.*, ([0-9]+) échec.*/\1/')))
	fi
fi
echo "banc a111 (inventaire des potions) : $checks vérification(s), $fails échec(s)"
exit $((fails > 0))
