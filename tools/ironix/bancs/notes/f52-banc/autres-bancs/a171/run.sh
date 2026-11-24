#!/usr/bin/env bash
# fusion52 (2026-11-15, petit chef n° 2) : a171 (copie a172) sur un arbre où Training.Treadmill.SideEntryOnly = false
# (a180-banc/regle-coupee.sh). Ses scénarios a38/effects posent Bob et Cid droit sur la bande du tapis ; la nouvelle règle
# d'a180 (entrée par un grand côté) est vérifiée par le banc a180. Arbre sans SideEntryOnly (avant a180) : regle-coupee.sh
# lance le banc sur l'arbre tel quel.
#   bash run.sh [racine du dépôt]
N="$(cd "$(dirname "$0")/../../.." && pwd)"
exec bash "$N/a180-banc/regle-coupee.sh" "$N/a172-banc/autres-bancs/a171/run.sh" repo "${1:-/f/StealAShop}"
