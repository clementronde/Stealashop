#!/usr/bin/env bash
# lot98 (petit chef 3) : a62 d'a401 (interrupteurs d'a401 coupés) avec Config/CashFlash d'a317 coupé aussi (flash/run.sh) :
# ce banc vérifie l'ancien rythme de l'encaissement ; L-299 est vérifié par le banc a317.
H="$(cd "$(dirname "$0")/../.." && pwd)"
exec bash "$H/pc3-lot98-bancs/flash/run.sh" "$H/a401-banc/autres-bancs/a62/run.sh" "$@"
