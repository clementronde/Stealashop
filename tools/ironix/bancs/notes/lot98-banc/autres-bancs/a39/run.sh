#!/usr/bin/env bash
# lot98-commun : a39 de pc3-lot98-bancs/cantin (UserInputService, sans outils de renaissance, Costs de ShopGrowth) corrigé
# par ../../corrige.sh (patches/a39.pl : DoubleSpeed en 3e gamepass, SpeedBoost retiré de l'onglet Boosts, a319).
N="$(cd "$(dirname "$0")/../../.." && pwd)"
exec bash "$N/lot98-banc/corrige.sh" a39 bash "$N/pc3-lot98-bancs/cantin/a39/run.sh" "$@"
