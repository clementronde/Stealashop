#!/usr/bin/env bash
# lot98 (petit chef 3) : a60 du lot96 (a308) sur l'arbre aux interrupteurs d'a401 coupés (a401-coupe.sh), avec
# Config/CashFlash d'a317 coupé aussi (flash/run.sh) : ce banc vérifie l'ancien rythme ; L-299 est vérifié par a317.
H="$(cd "$(dirname "$0")/../.." && pwd)"
exec bash "$H/pc3-lot98-bancs/flash/run.sh" "$H/a401-banc/a401-coupe.sh" "$H/a308-banc/autres-bancs/a60/run.sh" "$@"
