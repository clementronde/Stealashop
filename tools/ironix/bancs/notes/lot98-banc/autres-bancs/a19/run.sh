#!/usr/bin/env bash
# lot98-commun : a19 de pc3-lot98-bancs/cantin (sans outils de renaissance, Costs de ShopGrowth) corrigé par ../../corrige.sh
# (patches/a19.pl : « Unlock display (…) », a412).
N="$(cd "$(dirname "$0")/../../.." && pwd)"
exec bash "$N/lot98-banc/corrige.sh" a19 bash "$N/pc3-lot98-bancs/cantin/a19/run.sh" "$@"
