#!/usr/bin/env bash
# lot98 (petit chef 3) : a31 d'a262 + pc3-lot98-bancs/patches/a31.pl (Shared/ShopFloor, Config/ShopGrowth et Config/SkillTree
# dans le faux Roblox, lus par DataService et le ContractChecker depuis a280). Lanceur d'avant : a262-banc/autres-bancs/a31/run.sh.
H="$(cd "$(dirname "$0")/../.." && pwd)"
exec bash "$H/pc3-lot98-bancs/corrige.sh" a31 bash "$H/a262-banc/autres-bancs/a31/run.sh" "$@"
