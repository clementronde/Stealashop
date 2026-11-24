#!/usr/bin/env bash
# a310 (22/11) : banc a200 par la même chaîne que a224-banc/autres-bancs/a200 (a224 puis a213 corrige.sh), sur la copie
# a310 du banc (banc.sh, tests.swap.luau d'ici : S3 et S5 sortent de l'emprise élargie, à 3,5 au lieu de 2,6, avant de
# revenir par le côté). Le reste est inchangé.
N="$(cd "$(dirname "$0")/../../.." && pwd)"
exec bash "$N/a224-banc/corrige.sh" a200 "$N/a310-banc/autres-bancs/a200/inner.sh" "$@"
