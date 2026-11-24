#!/usr/bin/env bash
# a418 (23/11, variante A2 de Cantin : petits objets ×2, gros inchangés) : banc a203 de f66 (copie dans banc/, seules les
# tailles attendues de 1 et 10 kg changent : ×0,93 et ×2 ; revenus inchangés), corrigé à la volée par a262-banc/corrige.sh
# comme dans le lanceur commun.
S="$(cd "$(dirname "$0")/../../.." && pwd)"
H="$(cd "$(dirname "$0")" && pwd)"
exec bash "$S/a262-banc/corrige.sh" "a203" "$H/banc/run.sh" "$@"
