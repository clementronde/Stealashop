#!/usr/bin/env bash
# fusion62 (vague 66 + a226 déjà au lanceur) : a210 passe par la copie a218 (NewAuras = true : anciennes auras remises), elle-même
# enveloppée par a226-banc/avant.sh (valeurs d avant a226 ; sans teamSuffix dans AdvicePanel : la copie a218 telle quelle).
H="$(cd "$(dirname "$0")/../../.." && pwd)"
exec bash "$H/a226-banc/avant.sh" "$H/a218-banc/autres-bancs/a210/run.sh" "${1:-/f/StealAShop}"
