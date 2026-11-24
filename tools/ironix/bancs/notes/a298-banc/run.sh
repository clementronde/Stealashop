#!/usr/bin/env bash
# Banc a298 (21/11) : effets du plugin Framewisp rejoués par Controllers/UI/FramewispFx (Spin, Wiggle, Lean, Burst,
# Gleam de groupe, Stroke, assombrissement, script du plugin présent), reflet du bouton entier (SheenFx : rails du HUD,
# UIGradient Gleam, boutons d'achat de la boutique Robux), Gleam sur un texte ignoré par UiAttrFx, Features.FramewispFx.
# Faux Roblox et mise en place du banc a38 (a134-banc/autres-bancs/a38), lancé par a158-banc/corrige.sh comme le banc
# a285 ; scénarios tests.<partie>.luau d'ici (inner.sh). Arbre sans a298 (pas d'UI/FramewispFx) : « SAUTÉ ».
#   bash run.sh [racine du dépôt]
set -u
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop}"
ROOT="${ROOT%/src}"
if [ ! -f "$ROOT/src/client/Controllers/UI/FramewispFx.luau" ]; then
	echo "banc a298 (effets Framewisp, reflet des boutons) : SAUTÉ, pas de UI/FramewispFx dans $ROOT : 0 vérification(s), 0 échec(s)"
	exit 0
fi
exec bash "$H/../a158-banc/corrige.sh" a38 bash "$H/inner.sh" "$ROOT"
