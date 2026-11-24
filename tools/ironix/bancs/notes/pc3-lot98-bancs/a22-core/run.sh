#!/usr/bin/env bash
# lot98 (petit chef 3) : a22-core d'a262 + pc3-lot98-bancs/patches/a22-core.pl (Config/SkillTree dans le faux Roblox,
# lu par le checkFloor2 d'a280). Lanceur d'avant : a262-banc/autres-bancs/a22-core/run.sh.
H="$(cd "$(dirname "$0")/../.." && pwd)"
exec bash "$H/pc3-lot98-bancs/corrige.sh" a22-core bash "$H/a262-banc/autres-bancs/a22-core/run.sh" "$@"
