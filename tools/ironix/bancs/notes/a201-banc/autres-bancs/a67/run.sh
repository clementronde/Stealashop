#!/usr/bin/env bash
# a201 (vague 61, L-192) : banc a67, via ../lanceur.sh (repli sur le lanceur d a191 sans a201).
exec bash "$(cd "$(dirname "$0")/.." && pwd)/lanceur.sh" a67 "$@"
