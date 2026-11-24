#!/usr/bin/env bash
# a311 (22/11) : la copie a310 du banc a180 (a310-banc/autres-bancs/a180, lue sur place) sur l'arbre où
# Training.Treadmill.SideEntryMargin = 1,5 (../../marge-a310.sh : ses tapis n'ont pas de UseZone, zone X ±3 plus
# étroite que l'emprise de 2,25).
N="$(cd "$(dirname "$0")/../../.." && pwd)"
exec bash "$N/a311-banc/marge-a310.sh" "$N/a310-banc/autres-bancs/a180/run.sh" "${1:-/f/StealAShop}"
