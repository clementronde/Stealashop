#!/usr/bin/env bash
# lot98-commun : a170 par la chaîne d'a251 (patches/a170.sed, UI_Unbox revenu au contrat) sur la copie banc.sh de
# a170-banc/run.sh (a415 : remote DropCarried retiré, plus attendu ; son absence est contrôlée).
N="$(cd "$(dirname "$0")/../../.." && pwd)"
exec bash "$N/a251-banc/corrige.sh" a170 bash "$N/lot98-banc/autres-bancs/a170/banc.sh" "$@"
