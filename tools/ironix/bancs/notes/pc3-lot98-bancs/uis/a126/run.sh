#!/usr/bin/env bash
H="$(cd "$(dirname "$0")/../../.." && pwd)"
# lot98 (petit chef 3) : a126 avec UserInputService dans son faux Roblox (pc3-lot98-bancs/uis, a419).
exec bash "$H/pc3-lot98-bancs/uis/run.sh" "$H/a262-banc/autres-bancs/a126/run.sh" "$@"
