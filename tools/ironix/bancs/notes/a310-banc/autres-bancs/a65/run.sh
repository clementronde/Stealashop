#!/usr/bin/env bash
# a310 (22/11) : lanceur du banc a65 (a200-banc/autres-bancs/a65, règle d'a180 coupée) sur l'arbre où
# Training.Treadmill.SideEntryMargin = 0 (../../marge-zero.sh : Z2 sort de la bande à 2,7, dans l'emprise élargie).
N="$(cd "$(dirname "$0")/../../.." && pwd)"
exec bash "$N/a310-banc/marge-zero.sh" "$N/a200-banc/autres-bancs/a65/run.sh" "${1:-/f/StealAShop}"
