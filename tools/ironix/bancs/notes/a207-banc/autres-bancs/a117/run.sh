#!/usr/bin/env bash
# a207 (vague 63, L-201) : banc a117, via ../lanceur.sh (repli sur le lanceur d a201 sans a207).
exec bash "$(cd "$(dirname "$0")/.." && pwd)/lanceur.sh" a117 "$@"
