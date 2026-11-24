#!/usr/bin/env bash
# lot98-commun : a208 de pc3-lot98-bancs/cantin (copie a294, Costs de ShopGrowth) corrigé par ../../corrige.sh
# (patches/a208.pl : ×2 Speed devenu le gamepass DoubleSpeed, boost SpeedBoost retiré, a319), avec UserInputService
# dans son faux Roblox (pc3-lot98-bancs/uis : a419, Shared/Gamepad demandé par RebirthController au chargement).
N="$(cd "$(dirname "$0")/../../.." && pwd)"
exec bash "$N/lot98-banc/corrige.sh" a208 bash "$N/pc3-lot98-bancs/uis/run.sh" "$N/pc3-lot98-bancs/cantin/a208/run.sh" "$@"
