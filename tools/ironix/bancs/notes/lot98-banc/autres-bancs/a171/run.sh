#!/usr/bin/env bash
# lot98-commun : a171 = enveloppe cantin du lot98 (Costs de ShopGrowth, a280) + correction du lot96 (lot96-banc/patches/a171.pl :
# gamepass confirmé par Roblox, a274) + lot98-banc/patches/a171.pl (attentes changées par a317 et a319).
N="$(cd "$(dirname "$0")/../../.." && pwd)"
exec bash "$N/lot98-banc/corrige.sh" a171 bash "$N/lot96-banc/corrige.sh" a171 bash "$N/pc3-lot98-bancs/cantin/a171/run.sh" "$@"
