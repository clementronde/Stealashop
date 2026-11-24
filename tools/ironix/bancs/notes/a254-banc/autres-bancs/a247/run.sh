#!/usr/bin/env bash
# a254 (vague 73) : lanceur du banc a247 (a247-banc/run.sh) sur un arbre à Config/Announce.Enabled = false
# (../../annonce-coupee.sh) : son scénario lit l'annonce dans Notify ; UI_Announce est vérifié par le banc a254.
S="$(cd "$(dirname "$0")/../../.." && pwd)"
ARG="${1:-/f/StealAShop}"
shift || true
exec bash "$S/a254-banc/annonce-coupee.sh" "$S/a247-banc/run.sh" "$ARG" "$@"
