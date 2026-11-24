#!/usr/bin/env bash
# a247 (vague 72, L-216 point 8 et L-229) : chance du serveur en Robux (ServerLuck2, 4, 8 : file des tranches,
# annonce à tous, idempotence), lecture de l'attribut ServerLuck par StoreHeistService, son Shop_Buy du client.
# Faux Roblox, mise en place et aides du banc a38 (a134-banc/autres-bancs/a38), lancé par a158-banc/corrige.sh
# comme le banc a38 d'aujourd'hui ; scénario tests.serverluck.luau d'ici. Fichiers assemblés écrits ici.
# Arbre sans la chance du serveur (Monetization.ServerLuck absent) : « SAUTÉ ».
#   bash run.sh [racine du dépôt]
set -u
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop}"
ROOT="${ROOT%/src}"
if ! grep -q "ServerLuck = {" "$ROOT/src/shared/Config/Monetization.luau" 2>/dev/null; then
	echo "banc a247 (chance du serveur) : SAUTÉ, pas de Monetization.ServerLuck dans $ROOT : 0 vérification(s), 0 échec(s)"
	exit 0
fi
exec bash "$H/../a158-banc/corrige.sh" a38 bash "$H/inner.sh" "$ROOT"
