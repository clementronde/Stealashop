#!/usr/bin/env bash
# lot98 (petit chef 3) : a154 du lot96 (lot96-banc, remotes d'a314 et a410) + pc3-lot98-bancs/patches/a154.pl (FunnelStep,
# Disguise, Denounce, ajoutés après ItemSecured par a414 et a411).
H="$(cd "$(dirname "$0")/../.." && pwd)"
exec bash "$H/pc3-lot98-bancs/corrige.sh" a154 bash "$H/lot96-banc/autres-bancs/a154/run.sh" "$@"
