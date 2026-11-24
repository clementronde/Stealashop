#!/usr/bin/env bash
# a310 (22/11) : lanceur du banc a115 (a180-banc/autres-bancs/a115, règle d'a180 coupée) sur l'arbre où
# Training.Treadmill.SideEntryMargin = 0 (../../marge-zero.sh : S3, S4 et S8 sortent de la bande à 2,6, dans l'emprise élargie).
N="$(cd "$(dirname "$0")/../../.." && pwd)"
exec bash "$N/a310-banc/marge-zero.sh" "$N/a180-banc/autres-bancs/a115/run.sh" "${1:-/f/StealAShop}"
