#!/usr/bin/env bash
# Banc a284 (vague GC3, 23/11 : WindowHP de la régénération seule à Balance.Window.RegenSyncHz = 2) : la copie a284 du
# banc a08 (autres-bancs/a08/tests.luau) par la même chaîne que le banc a08 du lanceur commun (avant-cantin d'a262,
# avant d'a226, echelle1 d'a198). « SAUTÉ » sur un arbre sans RegenSyncHz.
H="$(cd "$(dirname "$0")/.." && pwd)"
exec bash "$H/a262-banc/avant-cantin.sh" "$H/a284-banc/autres-bancs/a08/c226.sh" "${1:-/f/StealAShop/src}"
