#!/usr/bin/env bash
# a244 (vague 72, Features.Rebirth = true) : banc a164 sur une copie où la renaissance est remise à false (../flag-off.sh) ;
# lanceur d avant : a203-banc/autres-bancs/a164/run.sh. La renaissance allumée est vérifiée par a244-banc.
H="$(cd "$(dirname "$0")/../../.." && pwd)"
exec bash "$H/a244-banc/autres-bancs/flag-off.sh" "$H/a203-banc/autres-bancs/a164/run.sh" "$@"
