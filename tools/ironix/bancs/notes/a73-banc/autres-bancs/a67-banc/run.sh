#!/usr/bin/env bash
# Copie d'a73 (2026-11-11, vague 24) du banc a67 : mêmes scénarios (v3, v3contract, settings, settingsoff), lancés
# sur la copie a73-banc/autres-bancs/a40-banc (ZoneName de la v3 = magasins de la zone). Sur un arbre sans a73,
# cette copie relance celle d'a67 : bonne avant et après la fusion.
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop}"
out=$(bash "$H/../a40-banc/run.sh" "$ROOT" v3 v3contract settings settingsoff)
code=$?
printf '%s\n' "$out" | sed 's/^banc a40 (index des objets)/banc a67 (index v3, réglages)/'
exit $code
