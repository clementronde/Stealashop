#!/usr/bin/env bash
# Banc a196, partie trail (vague 60, T-097) : le « ×2 » du trail en petit TextLabel (UiMotion.FloatGain.TrailExponent) au
# coin haut droit du nombre. Harnais du banc a155 copie a178 (a178-banc/autres-bancs/a155-banc, faux Roblox d'a60 copie
# a62, lus sur place), passé par a190-banc/corrige.sh a155 (Quint, Hud.TreadmillGain.Pieces = 1) ; ajouts purs au faux
# TextLabel (Font, TextXAlignment, TextYAlignment ; TextBounds 60 × 20 vient d ext-a60), comme le RichText d'a155. « SAUTÉ » sans TrailExponent.
set -u
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop}"
if ! grep -q "TrailExponent" "$ROOT/src/shared/Config/UiMotion.luau" 2>/dev/null; then
	echo "banc a196 trail : SAUTÉ, pas de FloatGain.TrailExponent : 0 vérification(s), 0 échec(s)"
	exit 0
fi
exec bash "$H/../../a190-banc/corrige.sh" a155 bash "$H/inner.sh" "$ROOT"
