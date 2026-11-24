#!/usr/bin/env bash
# lot98-commun : a181 = enveloppe cantin du lot98 (Costs de ShopGrowth, a280) + correction du lot96 (lot96-banc/patches/a181.pl :
# AncestryChanged du faux Instance, a283).
N="$(cd "$(dirname "$0")/../../.." && pwd)"
exec bash "$N/lot96-banc/corrige.sh" a181 bash "$N/pc3-lot98-bancs/cantin/a181/run.sh" "$@"
