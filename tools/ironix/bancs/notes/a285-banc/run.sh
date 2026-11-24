#!/usr/bin/env bash
# Banc a285 (21/11) : caisse exclusive de la boutique Robux (Items.Exclusives, don idempotent des lots x1, x3 et x10,
# crochet de Studio, rien sans Features.RobuxCrate), Ids DEV et PROD (Config/ProductIds), chance du serveur dans
# UI_EventBanner, réglages Gleam, IconHover et Idle (Wiggle, Fall) de Clément joués par UI/UiAttrFx.
# Faux Roblox, mise en place et aides du banc a38 (a134-banc/autres-bancs/a38), lancé par a158-banc/corrige.sh comme
# le banc a247 ; scénarios tests.<partie>.luau d'ici (inner.sh). Arbre sans a285 (pas de Config/ProductIds) : « SAUTÉ ».
#   bash run.sh [racine du dépôt]
set -u
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop}"
ROOT="${ROOT%/src}"
if [ ! -f "$ROOT/src/shared/Config/ProductIds.luau" ] || [ ! -f "$ROOT/src/client/Controllers/UI/UiAttrFx.luau" ]; then
	echo "banc a285 (caisse exclusive, Ids, chance du serveur, effets d'UI) : SAUTÉ, pas de Config/ProductIds ni de UI/UiAttrFx dans $ROOT : 0 vérification(s), 0 échec(s)"
	exit 0
fi
exec bash "$H/../a158-banc/corrige.sh" a38 bash "$H/inner.sh" "$ROOT"
