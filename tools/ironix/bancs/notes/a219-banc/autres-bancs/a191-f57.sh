#!/usr/bin/env bash
# a219 (vague 66, 2026-11-16) : banc a191 via f57-banc/corrige.sh (attribut Diamonds, Config/Boosts en ligne), sur la copie a219
# de son lanceur (autres-bancs/a191/run.sh : réserve qui prend tout, échange, PLACE).
N="$(cd "$(dirname "$0")/../.." && pwd)"
exec bash "$N/f57-banc/corrige.sh" a191 "$N/a219-banc/autres-bancs/a191/run.sh" "$@"
