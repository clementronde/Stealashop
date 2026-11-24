#!/usr/bin/env bash
# lot98 (petit chef 3) : a39 (version a262 « avant Cantin ») avec UserInputService dans son faux Roblox (pc3-lot98-bancs/uis,
# a419 : Shared/Gamepad), sur l'arbre sans outils de renaissance d'a407 (a407-banc/sans-outils.sh, comme a19, a134, a164).
# Le lanceur passe en plus par pc3-lot98-bancs/cantin (Costs de ShopGrowth, a280).
H="$(cd "$(dirname "$0")/../.." && pwd)"
ARG="${1:-/f/StealAShop}"
exec bash "$H/pc3-lot98-bancs/uis/run.sh" "$H/a407-banc/sans-outils.sh" "$H/a262-banc/autres-bancs-cantin/a39/run.sh" repo "${ARG%/src}"
