#!/usr/bin/env bash
# a245 (vague 72) : banc a167 comme fusion57 (f57-banc/corrige.sh), test du rendez-vous accepté à 16:00 Paris (a167-a184).
N="$(cd "$(dirname "$0")/../../.." && pwd)"
exec bash "$N/f57-banc/corrige.sh" a167 "$N/a245-banc/autres-bancs/a167/inner.sh" "$@"
