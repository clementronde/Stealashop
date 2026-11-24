#!/usr/bin/env bash
# lot98 (petit chef 3) : a93 par pc3-lot98-bancs/cantin (ligne Costs de ShopGrowth protégée de avant-cantin.pl, a280).
# Lanceur d'avant : $H/a267-banc/autres-bancs/a93/run.sh
H="$(cd "$(dirname "$0")/../../.." && pwd)"
exec bash "$H/pc3-lot98-bancs/cantin/run.sh" "$H/a267-banc/autres-bancs/a93/run.sh" "$@"
