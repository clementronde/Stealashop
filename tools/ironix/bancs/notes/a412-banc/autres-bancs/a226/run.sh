#!/usr/bin/env bash
# a412 (23/11) : comme a262-banc/autres-bancs-cantin/a226, avec la copie banc.sh (bandeau de zone en strengthText).
H="$(cd "$(dirname "$0")/../../.." && pwd)"
exec bash "$H/a262-banc/avant-cantin.sh" "$H/a412-banc/autres-bancs/a226/banc.sh" "$1"
